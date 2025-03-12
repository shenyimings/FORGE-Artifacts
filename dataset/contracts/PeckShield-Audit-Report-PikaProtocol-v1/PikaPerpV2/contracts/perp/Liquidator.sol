// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../access/Governable.sol";
import "./IPikaPerp.sol";
import "../oracle/IOracle.sol";

contract Liquidator is Governable {

    address public owner;
    address public pikaPerp;
    address public priceFeed;
    mapping (address => bool) public isKeeper;

    event PikaPerpSet(address pikaPerp);
    event PriceFeedSet(address priceFeed);
    event UpdateKeeper(address keeper, bool isAlive);
    event UpdateOwner(address owner);

    constructor(address _pikaPerp, address _priceFeed) public {
        owner = msg.sender;
        pikaPerp = _pikaPerp;
        priceFeed = _priceFeed;
    }

    function liquidateWithPrices(
        address[] memory tokens,
        uint256[] memory prices,
        uint256[] calldata positionIds)
    external onlyKeeper {
        IOracle(priceFeed).setPrices(tokens, prices);
        IPikaPerp(pikaPerp).liquidatePositions(positionIds);
    }

    function setPikaPerp(address _pikaPerp) external onlyOwner {
        pikaPerp = _pikaPerp;
        emit PikaPerpSet(_pikaPerp);
    }

    function setPriceFeed(address _priceFeed) external onlyOwner {
        priceFeed = _priceFeed;
        emit PriceFeedSet(_priceFeed);
    }

    function setOwner(address _owner) external onlyGov {
        owner = _owner;
        emit UpdateOwner(_owner);
    }

    function setKeeper(address _account, bool _isActive) external onlyOwner {
        isKeeper[_account] = _isActive;
        emit UpdateKeeper(_account, _isActive);
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Liquidator: !owner");
        _;
    }

    modifier onlyKeeper() {
        require(isKeeper[msg.sender], "Liquidator: !keeper");
        _;
    }

}
