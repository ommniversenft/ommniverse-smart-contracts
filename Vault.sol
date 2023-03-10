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
 
contract Vault is ERC721Holder, ERC1155Holder, ReentrancyGuard {
    using EnumerableSet for EnumerableSet.UintSet;
    using SafeMath for uint256;
    using SafeERC20 for OmmniverseToken;
 
    /// -------------------------------------
    /// -------- AUCTION INFORMATION --------
    /// -------------------------------------
 
    /// @notice the unix timestamp end time of the token auction
    uint256 public auctionEnd;
    /// @notice the current price of the token during an auction
    uint256 public livePrice;
    /// @notice the current user winning the token auction
    address public winning;
    bool public halfSupplyReached;
 
    enum State {
        inactive,
        live,
        ended,
        cancelled
    }
    State public auctionState;
 
    /// -----------------------------------
    /// -------- VAULT INFORMATION --------
    /// -----------------------------------
 
    /// @notice the governance contract which gets paid in ETH
    address public settings;
    address public curator;
    address public fractions;
    address public underlying;
    uint256 public fractionsID;
    uint256 public underlyingID;
    uint256 public fractionValue;
    uint256 public fractionSold;
 
    /// ------------------------
    /// -------- EVENTS --------
    /// ------------------------
 
    event BidPlaced(address indexed buyer, uint256 price);
    event AuctionEnded(address indexed buyer, uint256 price);
    event AuctionCancelled(address indexed curator, uint256 time);
    event AuctionStarted(address indexed buyer, uint256 price);
    event FractionRedeemed(address indexed owner, uint256 shares);
    event FractionBought(address indexed buyer, uint256 _amount);
    uint256 public supply;
    OmmniverseToken OmmiToken;
    uint256 public ommi_price; // in wei
 
    constructor(
        address _ommi,
        address _fractions,
        uint256 _fractionsID,
        address _underlying,
        uint256 _underlyingID,
        address _curator,
        uint256 _supply,
        uint256 _price
    ) {
        require(
            _ommi != address(0) &&
                _fractions != address(0) &&
                _underlying != address(0) &&
                _curator != address(0),
            "zero address is not allowed"
        );
        OmmiToken = OmmniverseToken(_ommi);
        settings = msg.sender;
        fractions = _fractions;
        fractionsID = _fractionsID;
        underlying = _underlying;
        underlyingID = _underlyingID;
        curator = _curator;
        supply = _supply;
        ommi_price = _price;
        fractionValue = 0;
        fractionSold = 0;
        auctionState = State.inactive;
    }
 
    function token() external view returns (address) {
        return underlying;
    }
 
    function id() external view returns (uint256) {
        return underlyingID;
    }
 
    function getRreservePrice() public view returns (uint256) {
        uint256 reserve_price = supply.mul(ommi_price).add(
            (supply.mul(ommi_price)).mul(30).div(100)
        );
        return reserve_price;
    }
 
    /// @notice buys fractions of the Nft. Must send price in Ommi
 
    function buyFraction(uint256 _amount) external nonReentrant {
        require(auctionState != State.live, "start:auction already started");
        require(
            OmmiToken.balanceOf(msg.sender) >= _amount * ommi_price,
            "Not enough balance"
        );
        if (halfSupplyReached) {
            OmmiToken.safeTransferFrom(
                msg.sender,
                curator,
                _amount * ommi_price
            );
        } else {
            if (OmmiToken.totalSupply() >= 3000000 * 10 * 18) {
                uint256 burn = (_amount * ommi_price) / 2;
                OmmiToken.safeTransferFrom(msg.sender, curator, burn);
                OmmiToken.burnFrom(msg.sender, burn);
            } else {
                halfSupplyReached = true;
                OmmiToken.safeTransferFrom(
                    msg.sender,
                    curator,
                    _amount * ommi_price
                );
            }
        }
        IFERC1155(fractions).safeTransferFrom(
            address(this),
            msg.sender,
            fractionsID,
            _amount,
            bytes("0")
        );
        fractionSold.add(_amount);
        emit FractionBought(msg.sender, _amount);
    }
 
    /// @notice kick off an auction. Must send reservePrice in Ommi
    function start(uint256 _amount) external nonReentrant {
        require(
            (auctionState == State.inactive) ||
                (auctionState == State.cancelled),
            "start:auction already started"
        );
        require((fractionSold == supply), "start:not all fractions sold");
 
        require(_amount >= getRreservePrice(), "Not enough balance");
        OmmiToken.safeTransferFrom(msg.sender, address(this), _amount);
 
        auctionEnd = block.timestamp + ISettings(settings).auctionLength();
        auctionState = State.live;
        livePrice = _amount;
        winning = msg.sender;
        emit AuctionStarted(msg.sender, _amount);
    }
 
    /// @notice an external function to bid on purchasing the vaults NFT.
    function bid(uint256 _amount) external nonReentrant {
        require(auctionState == State.live, "bid:auction is not live");
        require(_amount * 100 >= livePrice * 110, "bid:too low bid");
        OmmiToken.safeTransferFrom(msg.sender, address(this), _amount);
        require(block.timestamp < auctionEnd, "bid:auction ended");
 
        if (auctionEnd - block.timestamp <= 15 minutes) {
            auctionEnd += 15 minutes;
        }
        _sendOmmi(winning, livePrice);
        livePrice = _amount;
        winning = msg.sender;
        emit BidPlaced(msg.sender, _amount);
    }
 
    /// @notice an external function to end an auction after the timer has run out
    function cancel() external nonReentrant {
        require(auctionState == State.live, "end:vault has already closed");
        require(msg.sender == curator, "not curator");
        auctionState = State.cancelled;
        _sendOmmi(winning, livePrice);
        winning = address(0);
        emit AuctionCancelled(curator, block.timestamp);
    }
 
    /// @notice an external function to end an auction after the timer has run out
    function end() external nonReentrant {
        require(auctionState == State.live, "end:vault has already closed");
        require(block.timestamp >= auctionEnd, "end:auction live");
 
        IERC721(underlying).transferFrom(address(this), winning, underlyingID);
        auctionState = State.ended;
 
        _sendOmmi(
            ISettings(settings).feeReceiver(),
            livePrice * ((ISettings(settings).fee()) / 1000)
        );
        fractionValue =
            OmmiToken.balanceOf(address(this)) /
            IFERC1155(fractions).totalSupply(fractionsID);
        emit AuctionEnded(winning, livePrice);
    }
 
    /// @notice an external function to burn ERC1155 tokens to receive Ommi tokens from ERC721 token purchase
    function cash() external nonReentrant {
        require(auctionState == State.ended, "cash:vault not closed yet");
        uint256 bal = IFERC1155(fractions).balanceOf(msg.sender, fractionsID);
        require(bal > 0, "cash:no tokens to cash out");
        uint256 share = bal * fractionValue;
        IFERC1155(fractions).burn(msg.sender, fractionsID, bal);
        _sendOmmi(msg.sender, share);
        emit FractionRedeemed(msg.sender, share);
    }
 
    function _sendOmmi(address _to, uint256 _value) internal {
        OmmiToken.safeTransfer(_to, _value);
    }
 
    receive() external payable {}
}
