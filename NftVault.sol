// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
 
import "./interfaces/ISettings.sol";
import "./interfaces/IFERC1155.sol";
import "./OmmniverseToken.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
 
contract NftVault is ERC721Holder, ERC1155Holder, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    using SafeERC20 for OmmniverseToken;
 
    /// -----------------------------------
    /// -------- VAULT INFORMATION --------
    /// -----------------------------------
 
    /// @notice the governance contract which gets paid in ETH
    address public settings;
    address public curator;
    address public underlying;
    uint256 public underlyingID;
    bool public halfSupplyReached;
 
    /// ------------------------
    /// -------- EVENTS --------
    /// ------------------------
 
    event NftBought(address indexed buyer, uint256 tokenId);
 
    OmmniverseToken OmmiToken;
    uint256 nftPrice; // in wei
 
    constructor(
        address _ommi,
        address _underlying,
        uint256 _underlyingID,
        address _curator,
        uint256 _nftPrice
    ) {
        OmmiToken = OmmniverseToken(_ommi);
        settings = msg.sender;
        underlying = _underlying;
        underlyingID = _underlyingID;
        curator = _curator;
        nftPrice = _nftPrice;
    }
 
    function token() external view returns (address) {
        return underlying;
    }
 
    function id() external view returns (uint256) {
        return underlyingID;
    }
 
    /// @notice To buy the Nft. Must send price in Ommi
    function buyWholeNft() external payable nonReentrant {
        require(
            OmmiToken.balanceOf(msg.sender) >= nftPrice,
            "Not enough balance"
        );
        if (halfSupplyReached) {
            OmmiToken.safeTransferFrom(msg.sender, curator, nftPrice);
        } else {
            if (OmmiToken.totalSupply() >= 3000000 * 10 * 18) {
                uint256 burn = nftPrice / 2;
 
                OmmiToken.safeTransferFrom(msg.sender, curator, burn);
                OmmiToken.burnFrom(msg.sender, burn);
            } else {
                halfSupplyReached = true;
                OmmiToken.safeTransferFrom(msg.sender, curator, nftPrice);
            }
        }
        IERC721(underlying).safeTransferFrom(
            address(this),
            msg.sender,
            underlyingID
        );
        emit NftBought(msg.sender, underlyingID);
    }
 
    receive() external payable {}
}
