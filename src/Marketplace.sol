// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract Marketplace is Ownable, ERC721Holder {
    using SafeMath for uint256;
    using Address for address;

    uint256 constant public PercentUnit = 1000;
    uint256 public fee = 25;  // 2.5% for tx fee
	address public feeAddress;

    /* Orders to market NFT id => price */
    struct Order {
        uint256 id;
        address collection;
        uint256 tokenId;
        address owner;
        uint256 price;
        bool status;
    }
    
    address[] public collections;
    // order id => Order mapping
    mapping(uint256 => Order) public orders;
    uint256 public orderIndex;

    mapping(address => string) public users;
    mapping(address => bool) public isRegistered;

    struct History {
        uint256 timestamp;
        uint256 action;  // 1: list, 2: delist, 3: sold
        Order order;
    }
    mapping(address => uint256) public numberOfHistories;
    mapping(address => History[]) public histories;

    event ItemListed(Order order);
    event ItemDelisted(uint256 pairId);
    event Sold(address buyer, Order order);

    constructor () {}

    function registration(string memory username) external {
        require(!isRegistered[msg.sender], "User is registered already");
        isRegistered[msg.sender] = true;
        users[msg.sender] = username;
    }

    function list(address _collection, uint256 _tokenId, uint256 _price) OnlyItemOwner(_collection, _tokenId) isReg(msg.sender) public {
        require(_price > 0, "invalid price");
        IERC721 nft = IERC721(_collection);
        nft.safeTransferFrom(msg.sender, address(this), _tokenId);
        orderIndex = orderIndex.add(1);
        Order storage order = orders[orderIndex];

		order.id = orderIndex;
		order.collection = _collection;
		order.tokenId = _tokenId;
		order.owner = msg.sender;
		order.price = _price;
        order.status = true;

        emit ItemListed(order);
        uint256 historyIndex = numberOfHistories[msg.sender];
        History memory history;
        history.timestamp = block.timestamp;
        history.action = 1;
        history.order = order;
        histories[msg.sender].push(history);
        numberOfHistories[msg.sender] = historyIndex.add(1);
    }

    function delist(uint256 _id) external isReg(msg.sender) {
        require(orders[_id].status, "not exist");
        require(msg.sender == orders[_id].owner || msg.sender == owner(), "Error, you are not the owner");
        IERC721(orders[_id].collection).safeTransferFrom(address(this), msg.sender, orders[_id].tokenId);
        orders[_id].status = false;
        emit ItemDelisted(_id);
        uint256 historyIndex = numberOfHistories[msg.sender];
        History memory history;
        history.timestamp = block.timestamp;
        history.action =2;
        history.order = orders[_id];
        histories[msg.sender].push(history);
        numberOfHistories[msg.sender] = historyIndex.add(1);
    }

    function buy(uint256 _id) external payable isReg(msg.sender) {
        require(_id <= orderIndex && orders[_id].status, "Invalid item.");
        require(orders[_id].owner != msg.sender, "owner can not buy");
        
        Order memory order = orders[_id];
        uint256 totalAmount = order.price;
        require(msg.value >= totalAmount, "insufficient balance");
        
        uint256 feeAmount = totalAmount.mul(fee).div(PercentUnit);
        uint256 sellerAmount = totalAmount.sub(feeAmount);

        // transfer amount to seller
        (bool os, ) = payable(order.owner).call{value: sellerAmount}("");
        require(os, "Failed to withdraw"); 
        // transfer NFT token to buyer
        IERC721(order.collection).safeTransferFrom(address(this), msg.sender, order.tokenId);
        orders[_id].status = false;

        emit Sold(msg.sender, order);
        uint256 historyIndex = numberOfHistories[msg.sender];
        History memory history;
        history.timestamp = block.timestamp;
        history.action = 3;
        history.order = order;
        histories[msg.sender].push(history);
        numberOfHistories[msg.sender] = historyIndex.add(1);
    }

    function getOrder(uint256 orderId) public view returns(Order memory) {
        return orders[orderId];
    }

    function getUsername(address user) public view returns(string memory) {
        return users[user];
    }

    function getHistory(address user) public view returns(History[] memory) {
        return histories[user];
    }

    function withdraw() public onlyOwner {
        (bool os, ) = payable(feeAddress).call{value: address(this).balance}("");
        require(os, "Failed to withdraw"); 
    }

    modifier OnlyItemOwner(address tokenAddress, uint256 tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
        require(tokenContract.ownerOf(tokenId) == msg.sender);
        _;
    }

    modifier isReg(address userAddress) {
        require(isRegistered[userAddress] == true);
        _;
    }
}