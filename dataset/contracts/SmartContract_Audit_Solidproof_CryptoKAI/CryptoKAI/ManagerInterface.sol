// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.7.6;

interface ManagerInterface {
    function KAI(address _address) external view returns (bool);

    function Markets(address _address) external view returns (bool);

    function Farmers(address _address) external view returns (bool);

    function Stamina(uint256 level) external view returns (uint256);

    function StaminaTime() external view returns (uint256);

    function KAIBattle() external view returns (uint256);

    function KAIEggs() external view returns (uint256);

    function Percent() external view returns (uint256);

    function MarketFee() external view returns (uint256);

    function feeAddress() external view returns (address);
}