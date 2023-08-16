// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract STDNFT is ERC721, Ownable {
    using SafeMath for uint256;
    using Address for address;

    string collection_name;
    string collection_symbol;
    string collection_uri;
    string baseURI;

    struct Item {
        uint256 id;
        address creator;
        string uri;
    }
    uint256 currentID;
    mapping (uint256 => Item) public Items;

    event CollectionUriUpdated(string collectionUri);
    event CollectionNameUpdated(string collectionName);
    event CollectionSymbolUpdated(string collectionSymbol);
    event CollectionBaseURIUpdated(string collectionBaseURI);
    event CollectionOwnerUpdated(address newOwner);
    event ItemCreated(Item item);

    constructor(string memory _name, string memory _symbol, string memory _uri) ERC721(_name, _symbol) {
        collection_uri = _uri;
        collection_name = _name;
        collection_symbol = _symbol;
    }

    function contractURI() external view returns (string memory) {
        return collection_uri;
    }

    function name() public view virtual override returns (string memory) {
        return collection_name;
    }

    function symbol() public view virtual override returns (string memory) {
        return collection_symbol;
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(_exists(tokenId), "ERC721Metadata: URI query for nonexistent token");
        return Items[tokenId].uri;
    }

    function totalSupply() public view virtual returns (uint256) {
        return currentID;
    }
    
    /**
		Change & Get Collection Info
	 */
    function setCollectionURI(string memory newURI) external onlyOwner {
        collection_uri = newURI;
        emit CollectionUriUpdated(newURI);
    }

    function setName(string memory newname) external onlyOwner {
        collection_name = newname;
        emit CollectionNameUpdated(newname);
    }

    function setSymbol(string memory newname) external onlyOwner {
        collection_symbol = newname;
        emit CollectionSymbolUpdated(newname);
    }

    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit CollectionBaseURIUpdated(newBaseURI);
    }

    function addItem(string memory _tokenURI) external onlyOwner {
        currentID = currentID.add(1);
        _safeMint(msg.sender, currentID);
        Item memory item;
        item.id = currentID;
        item.creator = msg.sender;
        item.uri = _tokenURI;
        Items[currentID] = item;
        emit ItemCreated(item);
    }
    
    function creatorOf(uint256 _tokenId) public view returns (address) {
        return Items[_tokenId].creator;
    }
}