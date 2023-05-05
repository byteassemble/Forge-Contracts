// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract ChatApp {
    using SafeMath for uint256;
    using Address for address;
    
    uint256 public currentRoomId;
    struct Room {
        uint256 roomId;
        address owner;
        address[] members;
    }
    mapping(uint256=>Room) public rooms;

    event CreateRoom(uint256 _roomId, address _owner, address[] _members);
    event AddMember(uint256 _roomId, address _member);

    constructor () {}

    function createRoom(address[] memory members) external returns(uint256) {
        require(!checkItem(msg.sender, members), "Invalid members");
        currentRoomId = currentRoomId.add(1);
        Room memory room;
        room.roomId = currentRoomId;
        room.owner = msg.sender;
        room.members = members;
        rooms[currentRoomId] = room;
        emit CreateRoom(currentRoomId, msg.sender, members);
        return currentRoomId;
    }

    function addMember(uint256 roomId, address member) external {
        require(roomId <= currentRoomId, "Invalid Room Id");
        Room storage room = rooms[roomId];
        require(room.owner == msg.sender, "Room owner can add a member only.");
        require(msg.sender != member, "Invalid member.");
        require(!existMember(roomId, member), "The member exists already");
        room.members.push(member);
        emit AddMember(roomId, member);
    }

    function existMember(uint256 roomId, address newMember) public view returns(bool) {
        if (roomId > currentRoomId) return false;
        address[] memory members = rooms[roomId].members;
        bool isExist = false;
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i] == newMember) {
                isExist = true;
                break;
            }
        }
        return isExist;
    }

    function checkItem(address _member, address[] memory _members) public pure returns(bool) {
        bool isExist = false;
        for (uint256 i = 0; i < _members.length; i++) {
            if (_members[i] == _member) {
                isExist = true;
                break;
            }
        }
        return isExist;
    }
}