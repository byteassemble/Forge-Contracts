// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./RealestNFT.sol";

interface IRealestNFT {
	function initialize(string memory _name, string memory _uri, address creator, bool bPublic) external;	
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address);
    function creatorOf(uint256 _tokenId) external view returns (address);
	function royalties(uint256 _tokenId) external view returns (uint256);	
}

contract RealestMarket is Ownable, ERC721Holder {
    using SafeMath for uint256;
    using Address for address;

    uint256 constant public PercentUnit = 1000;
    uint256 public feeAdmin = 25;  // 2.5% for admin tx fee
	address public adminAddress;

    IERC20 public governanceToken;

    /* Pairs to market NFT _id => price */
	struct Pair {
		uint256 pair_id;
		address collection;
		uint256 token_id;
		address creator;
		address owner;
		uint256 price;
        uint256 creatorFee;
        bool bValid;
	}
    
    address[] public collections;
    // token id => Pair mapping
    mapping(uint256 => Pair) public pairs;
    uint256 public currentPairId;

    uint256 public totalEarning;  // total governance token
    uint256 public totalMarketCount;  // total markets count

    event CollectionCreated(address collection_address, address owner, string name, string uri, bool isPublic);
    event ItemListed(uint256 id, address collection, uint256 token_id, uint256 price, address creator, address owner, uint256 creatorFee);
	event ItemDelisted(uint256 id);
    event Swapped(address buyer, Pair pair);

    constructor () {}
    
    function initialize(address _governanceToken, address _adminAddress) external onlyOwner {
        governanceToken = IERC20(_governanceToken);
        adminAddress = _adminAddress;
    }

    function setFee(uint256 _feeAdmin, address _adminAddress) external onlyOwner {
        feeAdmin = _feeAdmin;
        adminAddress = _adminAddress;
    }

    function createCollection(string memory _name, string memory _uri, bool bPublic) public returns(address collection) {
        bytes memory bytecode = type(RealestNFT).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(_uri, _name, block.timestamp));
        assembly {
            collection := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IRealestNFT(collection).initialize(_name, _uri, msg.sender, bPublic);
        collections.push(collection);
        emit CollectionCreated(collection, msg.sender, _name, _uri, bPublic);
    }

    function list(address _collection, uint256 _token_id, uint256 _price) OnlyItemOwner(_collection,_token_id) public {
        require(_price > 0, "invalid price");
        IRealestNFT nft = IRealestNFT(_collection);
        nft.safeTransferFrom(msg.sender, address(this), _token_id);
        currentPairId = currentPairId.add(1);

		pairs[currentPairId].pair_id = currentPairId;
		pairs[currentPairId].collection = _collection;
		pairs[currentPairId].token_id = _token_id;
		pairs[currentPairId].creator = nft.creatorOf(_token_id);
        pairs[currentPairId].creatorFee = nft.royalties(_token_id);
		pairs[currentPairId].owner = msg.sender;
		pairs[currentPairId].price = _price;
        pairs[currentPairId].bValid = true;

        emit ItemListed(currentPairId, _collection, _token_id, _price, pairs[currentPairId].creator, msg.sender, pairs[currentPairId].creatorFee);
    }

    function delist(uint256 _id) external {
        require(pairs[_id].bValid, "not exist");
        require(msg.sender == pairs[_id].owner || msg.sender == owner(), "Error, you are not the owner");
        IRealestNFT(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pairs[_id].token_id);
        pairs[_id].bValid = false;
        emit ItemDelisted(_id);
    }

    function buy(uint256 _id) external ItemExists(_id) {
        require(pairs[_id].bValid, "invalid Pair id");
		require(pairs[_id].owner != msg.sender, "owner can not buy");

		Pair memory pair = pairs[_id];
		uint256 totalAmount = pair.price;
		uint256 token_balance = governanceToken.balanceOf(msg.sender);
		require(token_balance >= totalAmount, "insufficient token balance");

		// transfer governance token to adminAddress
		require(governanceToken.transferFrom(msg.sender, adminAddress, totalAmount.mul(feeAdmin).div(PercentUnit)), "failed to transfer Admin fee");
		
		// transfer governance token to creator
		require(governanceToken.transferFrom(msg.sender, pair.creator, totalAmount.mul(pair.creatorFee).div(PercentUnit)), "failed to transfer creator fee");
		
		// transfer governance token to owner
		uint256 ownerPercent = PercentUnit.sub(feeAdmin).sub(pair.creatorFee);
		require(governanceToken.transferFrom(msg.sender, pair.owner, totalAmount.mul(ownerPercent).div(PercentUnit)), "failed to transfer to owner");

		// transfer NFT token to buyer
		IRealestNFT(pairs[_id].collection).safeTransferFrom(address(this), msg.sender, pair.token_id);
		pairs[_id].bValid = false;
		totalEarning = totalEarning.add(totalAmount);
		totalMarketCount = totalMarketCount.add(1);

        emit Swapped(msg.sender, pair);
    }

    modifier OnlyItemOwner(address tokenAddress, uint256 tokenId) {
        IRealestNFT tokenContract = IRealestNFT(tokenAddress);
        require(tokenContract.ownerOf(tokenId) == msg.sender);
        _;
    }

    modifier ItemExists(uint256 id) {
        require(id <= currentPairId && pairs[id].pair_id == id, "Could not find item");
        _;
    }
}
