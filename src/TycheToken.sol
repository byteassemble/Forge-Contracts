// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../custom-lib/Auth.sol";

contract TycheToken is ERC20, Auth {
    using Address for address;

    string private _name = "Tyche Token";
    string private _symbol = "TCET";
    uint256 private _initialSupply = 100000000;

    constructor() ERC20(_name, _symbol) Auth(msg.sender) {
        _mint(msg.sender, _initialSupply * (10 ** decimals()));
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address _to, uint256 _amount) public authorized {
        _mint(_to, _amount);
    }

    function burn(uint256 _amount) public authorized {
        _burn(_msgSender(), _amount);
    }
}