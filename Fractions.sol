// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
 
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
contract Fractions is ERC1155, Ownable {
    using Strings for uint256;
 
    address[] public allowedVaultFactories;
    string private baseURI;
    mapping(address => bool) public minters;
    mapping(uint256 => uint256) private _totalSupply;
 
    uint256 public count;
 
    mapping(uint256 => address) public idToVault;
 
    constructor(
        string memory base
    ) ERC1155("") {
        count = 0;
        baseURI = base;
 
    }
 
     modifier onlyMinter() {
        require(minters[msg.sender]);
        _;
    }
 
    function addMinter(address minter) external onlyOwner {
        minters[minter] = true;
    }
 
    function removeMinter(address minter) external onlyOwner {
        minters[minter] = false;
    }
 
    /// Minter Function ///
    function mint(address vault, uint256 amount) external onlyMinter returns (uint256) {
        count++;
        idToVault[count] = vault;
        _mint(msg.sender, count, amount, "0");
        _totalSupply[count] = amount;
        return count;
    }
 
    function burn(address account, uint256 id, uint256 value) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        _burn(account, id, value);
        _totalSupply[id] -= value;
    }
 
    /// Public Functions ///
 
    function totalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }
 
    function uri(uint256 id) public view override returns (string memory) {
        return
            bytes(baseURI).length > 0
                ? string(abi.encodePacked(baseURI, id.toString(), ".json"))
                : baseURI;
    }
 
    function getCount() public view returns (uint256) {
        return count;
    }
 
}
