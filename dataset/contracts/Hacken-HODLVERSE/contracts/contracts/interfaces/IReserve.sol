// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IReserve {
    struct Withdrawer {
        bool isEligible;
        uint256 proportion;
        uint256 amountWithdrawn;
    }

    function money() external view returns (address);

    function moneyBalance() external view returns (uint256);

    function totalMoneyCollected() external view returns (uint256);

    function totalProportions() external view returns (uint256);

    function withdrawers(address withdrawer)
        external
        view
        returns (
            bool isEligible,
            uint256 proportion,
            uint256 amountWithdrawn
        );

    function updateBuyback(address _newAddress) external;

    function updateMoney(address _newAddress) external;

    function updateWithdrawer(address _oldWithdrawer, address _newWithdrawer)
        external;

    function deposit(uint256 _deposit) external;

    function withdrawRewards() external returns (uint256);

    function canWithdraw() external view returns (bool);

    function inCaseTokensGetStuck(address _token, address payable _to) external;
}
