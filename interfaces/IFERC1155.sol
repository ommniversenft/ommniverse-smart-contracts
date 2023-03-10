// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
 
interface IFERC1155 is IERC1155 {
 
    function getCount() external view  returns (uint256);
 
    function mint(address, uint256) external returns (uint256);
 
    function burn(
        address,
        uint256,
        uint256
    ) external;
 
    function totalSupply(uint256) external view returns (uint256);
}
