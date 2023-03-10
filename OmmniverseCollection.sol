// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
 
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
 
contract OmmniverseCollection is ERC721, ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
 
    Counters.Counter public _tokenIdCounter;
 
    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}
 
    function safeMint(address to, string memory uri) public onlyOwner {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }
 
    // The following functions are overrides required by Solidity.
 
    function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }
 
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
}
