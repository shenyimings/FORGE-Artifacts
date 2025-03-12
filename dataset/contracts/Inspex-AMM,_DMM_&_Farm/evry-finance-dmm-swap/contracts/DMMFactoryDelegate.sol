// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;

import "@openzeppelin/contracts/utils/EnumerableSet.sol";
import "./interfaces/IDMMFactoryDelegate.sol";
import "./DMMPool.sol";
import "./ManageUser.sol";

contract DMMFactoryDelegate is IDMMFactoryDelegate, ManageUser {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 internal constant BPS = 10000;

    address private feeAddress;
    uint16 private platformFeeBps = 2000;
    uint16 private governmentFeeBps;
    address public feeSetter;


    mapping(IERC20 => mapping(IERC20 => EnumerableSet.AddressSet)) internal tokenPools;
    mapping(IERC20 => mapping(IERC20 => address)) public getUnamplifiedPool;
    address[] public allPools;
    bytes32 private constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    event PoolCreated(
        IERC20 indexed token0,
        IERC20 indexed token1,
        address pool,
        uint32 ampBps,
        uint256 totalPool
    );
    event SetFeeConfiguration(address feeAddress, uint16 governmentFeeBps, uint16 platformFeeBps);
    event SetFeeSetter(address feeSetter);

    constructor(address _feeSetter, address _manage) public ManageUser(_manage) {
        feeSetter = _feeSetter;
        feeAddress = msg.sender;
    }

    function setFeeConfiguration(address _feeAddress, uint16 _governmentFeeBps, uint16 _platformFeeBps) external override {
        require(msg.sender == feeSetter, "DMM: FORBIDDEN");
        require(_governmentFeeBps >= 0 && _governmentFeeBps < 10000, "DMM: INVALID GOVERNMENT FEE");
        require(_platformFeeBps >= 0 && _platformFeeBps <= 10000, "DMM: INVALID PLATFORM FEE");
        feeAddress = _feeAddress;
        governmentFeeBps = _governmentFeeBps;
        platformFeeBps = _platformFeeBps;

        emit SetFeeConfiguration(_feeAddress, _governmentFeeBps, _platformFeeBps);
    }

    function setFeeSetter(address _feeSetter) external override {
        require(msg.sender == feeSetter, "DMM: FORBIDDEN");
        feeSetter = _feeSetter;

        emit SetFeeSetter(_feeSetter);
    }

    function allPoolsLength() external override view returns (uint256) {
        return allPools.length;
    }

    function getPools(IERC20 token0, IERC20 token1)
        external
        override
        view
        returns (address[] memory _tokenPools)
    {
        uint256 length = tokenPools[token0][token1].length();
        _tokenPools = new address[](length);
        for (uint256 i = 0; i < length; i++) {
            _tokenPools[i] = tokenPools[token0][token1].at(i);
        }
    }

    function getPoolsLength(IERC20 token0, IERC20 token1) external override view returns (uint256) {
        return tokenPools[token0][token1].length();
    }

    function getPoolAtIndex(
        IERC20 token0,
        IERC20 token1,
        uint256 index
    ) external override view returns (address pool) {
        return tokenPools[token0][token1].at(index);
    }

}
