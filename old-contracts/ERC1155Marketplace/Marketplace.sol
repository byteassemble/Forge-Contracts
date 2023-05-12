// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../custom-lib/Auth.sol";
import "./NFTCollection.sol";

contract Marketplace is Auth, ERC721Holder {
    using SafeMath for uint256;
    using Address for address;

    uint256 constant public PERCENTS_DIVIDER = 10000;
    uint256 public swapFee = 200;  // 2% for admin tx fee
    uint256 public whitelistFee = 100;  // 1% for whitelist users
    address public swapFeeAddress;
    uint256 constant public MIN_BID_INCREMENT_PERCENT = 500; // 5%

    /* Pairs to market NFT _id => price */
    struct Pair {
        uint256 pair_id;
        address collection;
        uint256 token_id;
        address owner;
        address currency;
        uint256 price;
        bool bValid;
    }
    // Bid struct to hold bidder and amount
    struct Bid {
        address from;
        uint256 bidPrice;
    }
    // Auction struct which holds all the required info
    struct Auction {
        uint256 auction_id;
        address collection;
        uint256 token_id;
        uint256 startTime;
        uint256 endTime;
        uint256 startPrice;
        address owner;
        address currency;
        bool active;
    }
    /** FreeBid Order Structure */
    struct Order {
        uint256 order_id;
        address collection;
        uint256 tokenId;
        address orderer;
        address currency;
        uint256 price;
        bool bValid;
    }
    uint256 public pairIndex;
    // pair index => Pair : All pairs
    mapping(uint256 => Pair) public pairs;

    uint256 public auctionIndex;
    // auction index => Auction : All Auctions
    mapping(uint256 => Auction) public auctions;
    // auction index => user bids : All Bids for an auction
    mapping (uint256 => Bid[]) public auctionBids;

    // orderId => Order mapping
    mapping(uint256 => Order) public orders;
    uint256 public orderIndex;

    // whitelist users to apply different marketing fee : user => bool
    mapping (address => bool) public whitelist;
    // whitelist collections to use in this marketplace : collection => bool
    mapping (address => bool) public w_collections;
    // currencies for marketplace : ERC20 address => bool
    mapping (address => bool) public currencies;
    
    // Fixed Item Events
    event ItemListed(Pair pair);
    event ItemDelisted(uint256 id);
    event Swapped(address buyer, Pair pair);

    // Auction Events
    event BidSuccess(address _from, uint256 _auctionId, uint256 _amount, uint256 _bidIndex);
    event AuctionCreated(Auction auction);
    event AuctionCanceled(uint _auctionId);
    event AuctionFinalized(Bid bid, Auction auction);

    // FreeBidding Events
    event OrderAdded(Order order);
    event OrderCanceled(uint256 order_id);
    event OrderSold(address seller, Order order);

    constructor () Auth(msg.sender) { 
        swapFeeAddress = msg.sender;
        currencies[address(0x0)] = true;
    }

    function setFee(uint256 _swapFee, uint256 _whitelistFee, address _swapFeeAddress) external authorized {
        swapFee = _swapFee;
        whitelistFee = _whitelistFee;
        swapFeeAddress = _swapFeeAddress;
    }

    function setWhitelist(address user, bool status) external authorized {
        whitelist[user] = status;
    }

    function setWCollection(address _collection, bool _status) external authorized {
        w_collections[_collection] = _status;
    }

    function setCurrency(address _currency, bool _status) external authorized {
        currencies[_currency] = _status;
    }

    /** Pair Management For Fixed Cost */
    function list(address _collection, uint256 _token_id, address _currency, uint256 _price) OnlyItemOwner(_collection, _token_id) external {
        require(currencies[_currency], "The currency is not registered for the marketplace!");
        require(_price > 0, "Invalid price");
        require(w_collections[_collection], "The collection is not approved by admin!");
        NFTCollection nft = NFTCollection(_collection);
        nft.safeTransferFrom(msg.sender, address(this), _token_id);
        // Create new pair item
        pairIndex = pairIndex.add(1);
        Pair memory item;
        item.pair_id = pairIndex;
        item.collection = _collection;
        item.token_id = _token_id;
        item.owner = msg.sender;
        item.currency = _currency;
        item.price = _price;
        item.bValid = true;
        pairs[pairIndex] = item;
        emit ItemListed(item);
    }

    function delist(uint256 _id) external {
        require(pairs[_id].bValid, "Invalid Pair id");
        require(pairs[_id].owner == msg.sender || isAuthorized(msg.sender), "Only owner can delist");
        NFTCollection(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pairs[_id].token_id);
        pairs[_id].bValid = false;
        pairs[_id].price = 0;
        emit ItemDelisted(_id);
    }

    function buy(uint256 _id) external payable {
        require(_id <= pairIndex && pairs[_id].bValid, "Invalid Pair Id");
        require(pairs[_id].owner != msg.sender, "Owner can not buy");

        Pair memory pair = pairs[_id];
        uint256 totalAmount = pair.price;
        bool erc20Flag = true;
        IERC20 currencyToken;
        if (pair.currency == address(0x0)) { erc20Flag = false; }
        if (erc20Flag) {
            currencyToken = IERC20(pair.currency);
            require(currencyToken.transferFrom(msg.sender, address(this), totalAmount), "Insufficient token balance");
        } else {
            require(msg.value >= totalAmount, "Insufficient balance");
        }
        
        address collectionOwner = getCollectionOwner(pair.collection);
        uint256 collectionRoyalty = getRoyalty(pair.collection);
        uint256 feeAmount;
        if (whitelist[msg.sender]) feeAmount = totalAmount.mul(whitelistFee).div(PERCENTS_DIVIDER);
        else feeAmount = totalAmount.mul(swapFee).div(PERCENTS_DIVIDER);
        uint256 sellerAmount = totalAmount.sub(feeAmount);
        if(swapFee > 0) {
            if (erc20Flag) {
                require(currencyToken.transfer(swapFeeAddress, feeAmount));
            } else {
                (bool fs, ) = payable(swapFeeAddress).call{value: feeAmount}("");
                require(fs, "Failed to send fee to fee address");
            }
        }
        if(collectionRoyalty > 0 && collectionOwner != address(0x0)) {
            uint256 royaltyAmount = totalAmount.mul(collectionRoyalty).div(PERCENTS_DIVIDER);
            if (erc20Flag) {
                require(currencyToken.transfer(collectionOwner, royaltyAmount));
            } else {
                (bool hs, ) = payable(collectionOwner).call{value: royaltyAmount}("");
                require(hs, "Failed to send collection royalty to collection owner");
            }
            sellerAmount = sellerAmount.sub(royaltyAmount);
        }
        if (erc20Flag) {
            require(currencyToken.transfer(pair.owner, sellerAmount));
        } else {
            (bool os, ) = payable(pair.owner).call{value: sellerAmount}("");
            require(os, "Failed to send to item owner");
        }
        
        // transfer NFT token to buyer
        NFTCollection(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pair.token_id);
        pairs[_id].bValid = false;

        emit Swapped(msg.sender, pair);
    }

    /** Auction Management With Bids */
    function createAuction(address _collection, uint256 _token_id, address _currency, uint256 _startPrice, uint256 _startTime, uint256 _endTime) 
    OnlyItemOwner(_collection, _token_id) public {
        require(block.timestamp < _endTime, "end timestamp have to be bigger than current time");
        require(w_collections[_collection], "The collection is not approved by admin!");
        NFTCollection nftCollection = NFTCollection(_collection);
        nftCollection.safeTransferFrom(msg.sender, address(this), _token_id);

        auctionIndex = auctionIndex.add(1);
        Auction memory newAuction;
        newAuction.auction_id = auctionIndex;
        newAuction.collection = _collection;
        newAuction.token_id = _token_id;
        newAuction.startPrice = _startPrice;
        newAuction.startTime = _startTime;
        newAuction.endTime = _endTime;
        newAuction.owner = msg.sender;
        newAuction.currency = _currency;
        newAuction.active = true;
        auctions[auctionIndex] = newAuction;
        emit AuctionCreated(newAuction);
    }

    function bidOnAuction(uint256 _auction_id, uint256 amount) external payable {
        require(_auction_id <= auctionIndex && auctions[_auction_id].active, "Invalid Auction Id");
        Auction memory myAuction = auctions[_auction_id];
        require(myAuction.owner != msg.sender, "Owner can not bid");
        require(myAuction.active, "not exist");
        require(block.timestamp < myAuction.endTime, "auction is over");
        require(block.timestamp >= myAuction.startTime, "auction is not started");

        uint256 bidsLength = auctionBids[_auction_id].length;
        uint256 tempAmount = myAuction.startPrice;
        Bid memory lastBid;
        if( bidsLength > 0 ) {
            lastBid = auctionBids[_auction_id][bidsLength - 1];
            tempAmount = lastBid.bidPrice.mul(PERCENTS_DIVIDER + MIN_BID_INCREMENT_PERCENT).div(PERCENTS_DIVIDER);
        }
        require(amount >= tempAmount, "too small balance");
        bool erc20Flag = true;
        IERC20 currencyToken;
        if (myAuction.currency == address(0x0)) { erc20Flag = false; }
        if (erc20Flag) {
            currencyToken = IERC20(myAuction.currency);
            require(currencyToken.transferFrom(msg.sender, address(this), amount), "transfer to contract failed");
        } else {
            require(msg.value >= amount, "smaller amount than bid amount");
        }
        if( bidsLength > 0 ) {
            if (erc20Flag) {
                require(currencyToken.transfer(lastBid.from, lastBid.bidPrice), "refund to last bidder failed");
            } else {
                (bool result, ) = payable(lastBid.from).call{value: lastBid.bidPrice}("");
                require(result, "Failed to send to the last bidder!");
            }
        }

        Bid memory newBid;
        newBid.from = msg.sender;
        newBid.bidPrice = amount;
        auctionBids[_auction_id].push(newBid);
        emit BidSuccess(msg.sender, _auction_id, newBid.bidPrice, bidsLength);
    }

    function finalizeAuction(uint256 _auction_id) public {
        require(_auction_id <= auctionIndex && auctions[_auction_id].active, "Invalid Auction Id");
        Auction memory myAuction = auctions[_auction_id];
        uint256 bidsLength = auctionBids[_auction_id].length;
        require(msg.sender == myAuction.owner || isAuthorized(msg.sender), "Only auction owner can finalize");
        // if there are no bids cancel
        if (bidsLength == 0) {
            NFTCollection(myAuction.collection).safeTransferFrom(address(this), myAuction.owner, myAuction.token_id);
            auctions[_auction_id].active = false;
            emit AuctionCanceled(_auction_id);
        } else {
            // the money goes to the auction owner
            Bid memory lastBid = auctionBids[_auction_id][bidsLength - 1];
            
            address collectionOwner = getCollectionOwner(myAuction.collection);
            uint256 collectionRoyalty = getRoyalty(myAuction.collection);
            uint256 feeAmount;
            if (whitelist[msg.sender]) feeAmount = lastBid.bidPrice.mul(whitelistFee).div(PERCENTS_DIVIDER);
            else feeAmount = lastBid.bidPrice.mul(swapFee).div(PERCENTS_DIVIDER);
            uint256 sellerAmount = lastBid.bidPrice.sub(feeAmount);
            bool erc20Flag = true;
            IERC20 currencyToken;
            if (myAuction.currency == address(0x0)) { erc20Flag = false; }
            if(swapFee > 0) {
                if (erc20Flag) {
                    require(currencyToken.transfer(swapFeeAddress, feeAmount));
                } else {
                    (bool fs, ) = payable(swapFeeAddress).call{value: feeAmount}("");
                    require(fs, "Failed to send fee to fee address");
                }
            }
            if(collectionRoyalty > 0 && collectionOwner != address(0x0)) {
                uint256 royaltyAmount = lastBid.bidPrice.mul(collectionRoyalty).div(PERCENTS_DIVIDER);
                if (erc20Flag) {
                    require(currencyToken.transfer(collectionOwner, royaltyAmount));
                } else {
                    (bool hs, ) = payable(collectionOwner).call{value: royaltyAmount}("");
                    require(hs, "Failed to send collection royalties to collection owner");
                }
                sellerAmount = sellerAmount.sub(royaltyAmount);
            }
            if (erc20Flag) {
                require(currencyToken.transfer(myAuction.owner, sellerAmount));
            } else {
                (bool os, ) = payable(myAuction.owner).call{value: sellerAmount}("");
                require(os, "Failed to send to item owner");
            }
            
            NFTCollection(myAuction.collection).safeTransferFrom(address(this), lastBid.from, myAuction.token_id);
            auctions[_auction_id].active = false;
            emit AuctionFinalized(lastBid, myAuction);
        }
    }

    function getBidsLength(uint256 _auction_id) public view returns(uint) {
        return auctionBids[_auction_id].length;
    }
    
    function getCurrentBids(uint256 _auction_id) public view returns(uint256, address) {
        uint256 bidsLength = auctionBids[_auction_id].length;
        // if there are bids refund the last bid
        if (bidsLength >= 0) {
            Bid memory lastBid = auctionBids[_auction_id][bidsLength - 1];
            return (lastBid.bidPrice, lastBid.from);
        }
        return (0, address(0));
    }
    
    /** Free Bidding System */
    function freeBid(address _collection, uint256 _tokenId, address _currency, uint256 _price) external {
        require(_price > 0, "Invalid price");
        require(_currency != address(0x0) && currencies[_currency], "Pay token is not valid!");
        require(w_collections[_collection], "The collection is not approved by admin!");
        
        NFTCollection nft = NFTCollection(_collection);
        require(nft.ownerOf(_tokenId) != msg.sender, "Owner can not bid");
        IERC20 payToken = IERC20(_currency);
        require(payToken.balanceOf(msg.sender) >= _price, "Insufficient balance!");
        require(payToken.allowance(msg.sender, address(this)) >= _price, "Check the token allowence!");
        orderIndex = orderIndex.add(1);
        orders[orderIndex].order_id = orderIndex;
        orders[orderIndex].collection = _collection;
        orders[orderIndex].tokenId = _tokenId;
        orders[orderIndex].orderer = msg.sender;
        orders[orderIndex].currency = _currency;
        orders[orderIndex].price = _price;
        orders[orderIndex].bValid = true;

        emit OrderAdded(orders[orderIndex]);
    }

    function calcelOrder(uint256 _id) external {
        require(orders[_id].bValid, "invalid Bid id");
        require(orders[_id].orderer == msg.sender, "only bidder can cancel");
        orders[_id].bValid = false;
        emit OrderCanceled(_id);
    }

    function sellOrder(uint256 _id) external {
        require(orders[_id].bValid, "Invalid Bid ID!");
        Order memory order = orders[_id];
        uint256 tokenId = order.tokenId;
        NFTCollection nft = NFTCollection(order.collection);
        require(nft.ownerOf(tokenId) == msg.sender, "Only owner can sell item!");
        address orderer = order.orderer;
        uint256 totalAmount = order.price;
        IERC20 payToken = IERC20(order.currency);
        require(payToken.transferFrom(orderer, address(this), totalAmount), "Insufficient balance!");
        
        address collectionOwner = getCollectionOwner(order.collection);
        uint256 collectionRoyalty = getRoyalty(order.collection);
        uint256 feeAmount;
        if (whitelist[msg.sender]) feeAmount = totalAmount.mul(whitelistFee).div(PERCENTS_DIVIDER);
        else feeAmount = totalAmount.mul(swapFee).div(PERCENTS_DIVIDER);
        uint256 sellerAmount = totalAmount.sub(feeAmount);
        if(swapFee > 0) {
            require(payToken.transfer(swapFeeAddress, feeAmount), "Failed to send fee to fee address.");
        }
        if(collectionRoyalty > 0 && collectionOwner != address(0x0)) {
            uint256 royaltyAmount = totalAmount.mul(collectionRoyalty).div(PERCENTS_DIVIDER);
            require(payToken.transfer(collectionOwner, royaltyAmount), "Failed to send collection royalty to collection owner.");
            sellerAmount = sellerAmount.sub(royaltyAmount);
        }
        require(payToken.transfer(msg.sender, sellerAmount), "Failed to send to item owner.");
        // Transfer NFT token to bidder
        nft.safeTransferFrom(msg.sender, orderer, tokenId);
        orders[_id].bValid = false;
        emit OrderSold(msg.sender, orders[_id]);
    }

    function getRoyalty(address collection) view internal returns(uint256) {
        NFTCollection nft_collection = NFTCollection(collection);
        try nft_collection.royaltyInfo(1, PERCENTS_DIVIDER) returns (address, uint256 _salePrice) {
            return _salePrice;
        } catch {
            return 0;
        }
    }

    function getCollectionOwner(address collection) view internal returns(address) {
        NFTCollection nft_collection = NFTCollection(collection); 
        try nft_collection.owner() returns (address collection_owner) {
            return collection_owner;
        } catch {
            try nft_collection.royaltyInfo(1, PERCENTS_DIVIDER) returns (address _receiver, uint256) {
                return _receiver;
            } catch {
                return address(0x0);
            }
        }
    }

    modifier OnlyItemOwner(address _collection, uint256 _tokenId) {
        NFTCollection collectionContract = NFTCollection(_collection);
        require(collectionContract.ownerOf(_tokenId) == msg.sender);
        _;
    }

    function withdraw() external payable authorized {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }
}