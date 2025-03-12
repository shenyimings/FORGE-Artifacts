// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IExchangerAdapterProvider {
    function getExchangerAdapter(byte flag) external view returns (address exchangerAdapter);
}
