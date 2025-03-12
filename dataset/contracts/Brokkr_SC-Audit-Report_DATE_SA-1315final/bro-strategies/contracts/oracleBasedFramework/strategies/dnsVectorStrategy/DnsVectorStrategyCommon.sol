// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import "./DnsVectorStrategyStorageLib.sol";

library DnsVectorStrategyCommon {
    error InvalidPangolinPair();

    uint256 public constant VARIABLE_DEBT = 2;
    uint256 public constant AAVE_FIXED_DECIMAL_FACTOR = 10**4;

    function getPangolinLpBalance() internal view returns (uint256) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        return
            strategyStorage
                .pangolinMiniChef
                .userInfo(strategyStorage.pangolinPoolId, address(this))
                .amount;
    }

    function getPangolinLpTotalSupply() internal view returns (uint256) {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        return strategyStorage.pangolinPair.totalSupply();
    }

    function getPangolinLpReserve(address token0, address token1)
        internal
        view
        returns (uint256 reserve0, uint256 reserve1)
    {
        DnsVectorStorage storage strategyStorage = DnsVectorStorageLib
            .getStorage();

        (uint256 _reserve0, uint256 _reserve1, ) = strategyStorage
            .pangolinPair
            .getReserves();

        address _token0 = strategyStorage.pangolinPair.token0();
        address _token1 = strategyStorage.pangolinPair.token1();

        if (_token0 == token0 && _token1 == token1) {
            reserve0 = _reserve0;
            reserve1 = _reserve1;
        } else if (_token0 == token1 && _token1 == token0) {
            reserve0 = _reserve1;
            reserve1 = _reserve0;
        } else {
            revert InvalidPangolinPair();
        }
    }
}
