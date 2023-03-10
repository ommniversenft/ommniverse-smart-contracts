//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
interface ISettings {
    function fee() external view returns (uint256);
 
    function auctionLength() external view returns (uint256);
 
    function feeReceiver() external view returns (address);
}
