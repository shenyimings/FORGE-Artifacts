// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IReferral {
    function set(address _from, address _to) external;

    function onHopeCommission(address _from, address _to, uint256 _hopeAmount) external;

    function refOf(address _to) external view returns (address);
}
