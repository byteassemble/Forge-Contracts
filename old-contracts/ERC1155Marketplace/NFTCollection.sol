// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFTCollection is ERC721Enumerable, ERC2981, Ownable {
    using Strings for uint256;
    string base_uri;

    constructor() ERC721("Common Collection", "COCO") Ownable() {
        _setDefaultRoyalty(msg.sender, 500);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Enumerable, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function updateRoaylty(uint96 newRoaylty) external onlyOwner {
        _setDefaultRoyalty(owner(), newRoaylty);
    }

    function _baseURI() internal view override returns (string memory) {
        return base_uri;
    }

    function updateBaseURI(string memory newBaseURI) external onlyOwner {
        base_uri = newBaseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);
        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0
            ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json"))
            : "";
    }
}
