// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ITreasury {
    function hasPool(address _address) external view returns (bool);

    function minting_fee() external view returns (uint256);

    function redemption_fee() external view returns (uint256);

    function reserve_share_state() external view returns (uint8);

    function collateralReserve() external view returns (address);

    function profitSharingFund() external view returns (address);

    function darkInsuranceFund() external view returns (address);

    function globalCollateralBalance(uint256) external view returns (uint256);

    function globalCollateralValue(uint256) external view returns (uint256);

    function globalCollateralTotalValue() external view returns (uint256);

    function globalDarkBalance() external view returns (uint256);

    function globalDarkValue() external view returns (uint256);

    function globalShareBalance() external view returns (uint256);

    function globalShareValue() external view returns (uint256);

    function getEffectiveCollateralRatio() external view returns (uint256);

    function requestTransfer(address token, address receiver, uint256 amount) external;

    function requestBurnShare(uint256 _fee) external;

    function requestTransferDarkFee(uint256 _fee) external;

    function reserveReceiveDark(uint256 _amount) external;

    function reserveReceiveShare(uint256 _amount) external;

    function info()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint8
        );
}
