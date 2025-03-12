// SPDX-License-Identifier: WTFPL License
pragma solidity >=0.6.0;

interface ILamaHerd {
    function setShepherd(address lama, address shepherd) external;

    function getShepherd(address lama) external view returns (address);

    function payRefFees(address lama, uint256 amount) external;
}
