// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
 
interface OERC721 is IERC721 {
    function burn(uint256) external;
}
