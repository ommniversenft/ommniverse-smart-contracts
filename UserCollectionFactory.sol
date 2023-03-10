// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
 
import "./UserCollection.sol";
 
contract UserCollectionFactory {
    address[] public collections;
    // Event for new collection created
    event UserCollectionCreated(
        address indexed collectionAddress,
        string _name,
        string _symbol
    );
 
    mapping(string => bool) private names;
    mapping(string => bool) private symbols;
 
    function mintContract(string memory _name, string memory _symbol) external {
        require(!isAlreadyTaken(_name, _symbol), "Already taken");
        address userCollection = address(new UserCollection(_name, _symbol));
        collections.push(userCollection);
        names[_name] = true;
        names[_symbol] = true;
        emit UserCollectionCreated(userCollection, _name, _symbol);
    }
 
    function getLastCollection() external view returns (uint256) {
        return (collections.length - 1);
    }
 
    function isAlreadyTaken(
        string memory _name,
        string memory _symbol
    ) public view returns (bool) {
        if (names[_name] && names[_symbol]) {
            return true;
        } else {
            return false;
        }
    }
}
