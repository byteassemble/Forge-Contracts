// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../custom-lib/Auth.sol";

contract MultiSender is Auth {
    using Address for address;

    IERC20 public token = IERC20(0xe4e8e6878718bfe533702D4a6571Eb74D79b0915);
    event BatchTransfer(address token, address[] to, uint256 amount);

    constructor() Auth(msg.sender) {}

    function batchTransfer(address[] memory _recipients, uint256 _amount) public returns (bool) {
        uint256 senderBalance = token.balanceOf(msg.sender);
        require(senderBalance >= (_amount * _recipients.length), "Insufficient balance");
        require(token.allowance(msg.sender, address(this)) >= (_amount * _recipients.length), "Amount is not approved!");

        for (uint256 i = 0; i < _recipients.length; i++) {
            require(token.transferFrom(msg.sender, _recipients[i], _amount), "Transfer failed");
        }
        emit BatchTransfer(address(token), _recipients, _amount);
        return true;
    }

    function updateToken(IERC20 _token) public authorized {
        token = _token;
    }
}