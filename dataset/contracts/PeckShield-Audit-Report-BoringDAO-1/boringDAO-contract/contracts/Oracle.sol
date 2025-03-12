// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interface/IOracle.sol";

contract Oracle is AccessControl, IOracle {
    bytes32 public ORACLE_ROLE = "ORACLE_ROLE";

    mapping(bytes32 => uint256) public priceOf;

    constructor() public {
        _setupRole(ORACLE_ROLE, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function setPrice(bytes32 _symbol, uint256 _price) public override  onlyOracle{
        priceOf[_symbol] = _price;
    }

    function setMultiPrice(bytes32[] memory _symbols, uint[] memory _prices) public onlyOracle{
        require(_symbols.length == _prices.length);
        for (uint i=0; i < _symbols.length; i++) {
            priceOf[_symbols[i]] = _prices[i];
        }
    }

    function getPrice(bytes32 _symbol) public override view returns (uint256) {
        require(priceOf[_symbol] != uint256(0), "price is not exist");
        return priceOf[_symbol];
    }

    modifier onlyOracle {
        require(hasRole(ORACLE_ROLE, msg.sender), "Caller is not a oracle");
        _;
    }
}
