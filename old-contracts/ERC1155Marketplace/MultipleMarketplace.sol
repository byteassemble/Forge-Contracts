// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../custom-lib/Auth.sol";
import "./MultipleCollection.sol";

contract MultipleMarketplace is Auth, ERC1155Holder {
    using SafeMath for uint256;
    using Address for address;

    uint256 constant public PERCENTS_DIVIDER = 10000;
    uint256 public swapFee = 200;  // 2% for admin tx fee
    uint256 public whitelistFee = 100;  // 1% for whitelist users
    address public swapFeeAddress;
    uint256 constant public MIN_BID_INCREMENT_PERCENT = 500; // 5%

    struct Pair {
        uint256 pair_id;
        address collection;
        uint256 tokenId;
        address owner;
        address currency;
        uint256 balance;
        uint256 price;
        bool bValid;
    }
    uint256 public pairIndex = 0;
    // pair index => Pair : All pairs
    mapping(uint256 => Pair) public pairs;
    /** FreeBid Order Structure */
    struct Order {
        uint256 order_id;
        address collection;
        uint256 tokenId;
        address orderer;
        address currency;
        uint256 amount;
        uint256 price;
        bool bValid;
    }
    uint256 public orderIndex = 0;
    // orderId => Order mapping
    mapping(uint256 => Order) public orders;

    // whitelist users to apply different marketing fee : user => bool
    mapping (address => bool) public whitelist;
    // whitelist collections to use in this marketplace : collection => bool
    mapping (address => bool) public w_collections;
    // currencies for marketplace : ERC20 address => bool
    mapping (address => bool) public currencies;

    event ItemListed(Pair pair);
    event ItemDelisted(uint256 pair_id);
    event ItemSwapped(address buyer, uint256 id, uint256 amount, Pair pair);

    event OrderAdded(Order order);
    event OrderCanceled(uint256 order_id);
    event OrderSold(address seller, Order order, uint256 id, uint256 amount);

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

    function list(address _collection, uint256 _tokenId, address _currency, uint256 _amount, uint256 _price) external {
        require(_price > 0, "invalid price");
        require(_amount > 0, "invalid amount");
        require(w_collections[_collection], "The collection is not approved by admin!");
        MultipleCollection nft = MultipleCollection(_collection);
        uint256 nft_token_balance = nft.balanceOf(msg.sender, _tokenId);
        require(nft_token_balance >= _amount, "invalid amount : amount have to be smaller than NFT balance");
        nft.safeTransferFrom(msg.sender, address(this), _tokenId, _amount, "List");
        // Create new pair item
        pairIndex = pairIndex.add(1);
        Pair memory item;
        item.pair_id = pairIndex;
        item.collection = _collection;
        item.tokenId = _tokenId;
        item.owner = msg.sender;
        item.currency = _currency;
        item.balance = _amount;
        item.price = _price;
        item.bValid = true;
        pairs[pairIndex] = item;
        emit ItemListed(item);
    }

    function delist(uint256 _id) external {
        require(pairs[_id].bValid, "Invalid Pair id");
        require(pairs[_id].owner == msg.sender || isAuthorized(msg.sender), "Only owner can delist");
        MultipleCollection(pairs[_id].collection).safeTransferFrom(address(this), pairs[_id].owner, pairs[_id].tokenId, pairs[_id].balance, "Delist Marketplace");
        pairs[_id].balance = 0;
        pairs[_id].bValid = false;
        emit ItemDelisted( _id);
    }

    function buy(uint256 _id, uint256 _amount) external payable {
        require(_id <= pairIndex && pairs[_id].bValid, "Invalid Pair id");
        require(pairs[_id].balance >= _amount, "Insufficient NFT balance");

        Pair memory pair = pairs[_id];
        uint256 totalAmount = pair.price.mul(_amount);
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
        MultipleCollection(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pair.tokenId, _amount, "Buy from Marketplace");

        pairs[_id].balance = pairs[_id].balance.sub(_amount);
        if (pairs[_id].balance == 0) {
            pairs[_id].bValid = false;
        }
        emit ItemSwapped(msg.sender, _id, _amount, pairs[_id]);
    }

    /** Free Bidding System */
    function freeBid(address _collection, uint256 _tokenId, address _currency, uint256 _amount, uint256 _price) external {
        require(_price > 0, "Invalid price");
        require(_amount > 0, "Invalid amount : amount have to be bigger than zero");
        require(_currency != address(0x0) && currencies[_currency], "Pay token is not valid!");
        require(w_collections[_collection], "The collection is not approved by admin!");

        orderIndex = orderIndex.add(1);
        orders[orderIndex].order_id = orderIndex;
        orders[orderIndex].collection = _collection;
        orders[orderIndex].tokenId = _tokenId;
        orders[orderIndex].orderer = msg.sender;
        orders[orderIndex].currency = _currency;
        orders[orderIndex].amount = _amount;
        orders[orderIndex].price = _price;
        orders[orderIndex].bValid = true;

        emit OrderAdded(orders[orderIndex]);
    }

    function calcelOrder(uint256 _id) external {
        require(orders[_id].bValid, "Invalid Bid id");
        require(orders[_id].orderer == msg.sender, "Only bidder can cancel");
        orders[_id].amount = 0;
        orders[_id].bValid = false;
        emit OrderCanceled(_id);
    }

    function sellOrder(uint256 _id, uint256 _amount) external {
        require(orders[_id].bValid, "Invalid Bid ID!");
        require(orders[_id].amount >= _amount, "Insufficient selling amount");

        Order memory order = orders[_id];
        uint256 newAmount = orderPayment(order, _amount);
        order.amount = order.amount.sub(newAmount);
        if (order.amount == 0) {
            order.bValid = false;
        }
        orders[_id] = order;
        emit OrderSold(msg.sender, orders[_id], _id, newAmount);
    }

    function orderPayment(Order memory order, uint256 _amount) internal returns (uint256) {
        address orderer = order.orderer;
        MultipleCollection nft = MultipleCollection(order.collection);
        uint256 tokenId = order.tokenId;

        uint256 nft_own_balance = nft.balanceOf(msg.sender, tokenId);
        uint256 newAmount = 0;
        if (nft_own_balance > _amount) { newAmount = _amount; }
        else { newAmount = nft_own_balance; }
        uint256 totalAmount = order.price.mul(newAmount);
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
        nft.safeTransferFrom(msg.sender, orderer, tokenId, newAmount, "Sell to bidder");
        return newAmount;
    }

    function getRoyalty(address collection) view internal returns(uint256) {
        MultipleCollection nft_collection = MultipleCollection(collection);
        try nft_collection.royaltyInfo(1, PERCENTS_DIVIDER) returns (address, uint256 _salePrice) {
            return _salePrice;
        } catch {
            return 0;
        }
    }

    function getCollectionOwner(address collection) view internal returns(address) {
        MultipleCollection nft_collection = MultipleCollection(collection); 
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

    function withdraw() external payable authorized {
        (bool success, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(success);
    }
}