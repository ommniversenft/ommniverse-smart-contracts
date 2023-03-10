// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
 
import "./Vault.sol";
import "./interfaces/IFERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
 
contract VaultFactory is ERC721Holder, ERC1155Holder {
    /// @notice the number of ERC721 vaults
    uint256 public vaultCount;
 
    /// @notice the fee denominator
    uint256 public fee;
 
    /// @notice the auction length
    uint256 public auctionLength;
 
    /// @notice the mapping of vault number to vault contract
    mapping(uint256 => address) public vaults;
 
    /// @notice a settings contract controlled by governance
    address public feeReceiver;
    /// @notice the fractional ERC1155 NFT contract
    address public fractions;
    /// @notice ommi token address
    address public ommi;
 
    event VaultAdded(
        address indexed token,
        uint256 id,
        uint256 fractionId,
        address indexed vault,
        uint256 vaultId,
        uint256 price
    );
 
    // fee uint range 1 - 200. here 1 = 0.1%, 200 = 20%
    constructor(
        address _fractions,
        address _ommi,
        address _feeReceiver,
        uint256 _fee,
        uint256 _auctionLength
    ) {
        require(
            _fractions != address(0) &&
                _ommi != address(0) &&
                _feeReceiver != address(0),
            "zero address is not allowed"
        );
        require(
            _auctionLength > 172800 && _auctionLength <= 604800,
            "Auction length in range"
        );
        require(_fee <= 200, "Fee not in range");
        fractions = _fractions;
        ommi = _ommi;
        feeReceiver = _feeReceiver;
        fee = _fee;
        auctionLength = _auctionLength;
    }
 
    /// @notice the function to mint a new vault
    /// @param _token the ERC721 token address fo the NFT
    /// @param _id the uint256 ID of the token
    /// @param _amount the amount of tokens to
    /// @return the ID of the vault
    function mintVault(
        address _token,
        uint256 _id,
        uint256 _amount,
        uint256 _price
    ) external returns (address) {
        uint256 count = IFERC1155(fractions).getCount() + 1;
 
        address vault = address(
            new Vault(
                ommi,
                fractions,
                count,
                _token,
                _id,
                msg.sender,
                _amount,
                _price
            )
        );
 
        uint256 fractionId = IFERC1155(fractions).mint(vault, _amount);
        require(count == fractionId, "mismatch");
 
        IERC721(_token).safeTransferFrom(msg.sender, vault, _id);
        IFERC1155(fractions).safeTransferFrom(
            address(this),
            vault,
            fractionId,
            _amount,
            bytes("0")
        );
        vaults[vaultCount] = vault;
        emit VaultAdded(_token, _id, fractionId, vault, vaultCount, _price);
        vaultCount++;
        return vault;
    }
}
