// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
 
import "./NftVault.sol";
import "./interfaces/IFERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
 
contract NftVaultFactory is ERC721Holder, ERC1155Holder {
    /// @notice the number of ERC721 nftVaults
    uint256 public nftVaultCount;
 
    /// @notice the fee denominator
    uint256 public fee;
 
    /// @notice the mapping of vault number to vault contract
    mapping(uint256 => address) public nftVaults;
 
    /// @notice a settings contract 
    address public feeReceiver;
 
    /// @notice allowed collection contract address 
    address public allowedCollection;
 
    /// @notice ommi token address
    address public ommi;
 
    event VaultAdded(
        address indexed token,
        uint256 id,
        address indexed vault,
        uint256 vaultId
    );
 
    constructor(address _ommi, address _feeReceiver, uint256 _fee, address _allowedCollection) {
        require(
            _ommi != address(0) && _feeReceiver != address(0) && _allowedCollection != address(0),
            "zero address is not allowed"
        );
        require(_fee <= 200, "Fee not in range");
        ommi = _ommi;
        feeReceiver = _feeReceiver;
        fee = _fee;
        allowedCollection = _allowedCollection;
    }
 
    /// @notice the function to mint a new vault
    /// @param _token the ERC721 token address fo the NFT
    /// @param _id the uint256 ID of the token
    /// @return the ID of the vault
    function mintNftVault(
        address _token,
        uint256 _id,
        uint256 _nftPrice
    ) external returns (address) {
        require(allowedCollection == _token, "Not allowed");
        address vault = address(
            new NftVault(ommi, _token, _id, msg.sender, _nftPrice)
        );
        IERC721(_token).safeTransferFrom(msg.sender, vault, _id);
        nftVaults[nftVaultCount] = vault;
        emit VaultAdded(_token, _id, vault, nftVaultCount);
        nftVaultCount++;
        return vault;
    }
}
