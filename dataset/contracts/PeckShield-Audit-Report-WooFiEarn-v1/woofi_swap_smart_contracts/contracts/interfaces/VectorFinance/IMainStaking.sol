// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

interface IMainStaking {
    function setXPTP(address _xPTP) external;

    function addFee(
        uint256 max,
        uint256 min,
        uint256 value,
        address to,
        bool isPTP,
        bool isAddress
    ) external;

    function setFee(uint256 index, uint256 value) external;

    function setCallerFee(uint256 value) external;

    function deposit(
        address token,
        uint256 amount,
        address sender
    ) external;

    function harvest(address token, bool isUser) external;

    function withdraw(
        address token,
        uint256 _amount,
        uint256 _slippage,
        address sender
    ) external;

    function stakePTP(uint256 amount) external;

    function stakeAllPtp() external;

    function claimVePTP() external;

    function getStakedPtp() external;

    function getVePtp() external;

    function unstakePTP() external;

    function pendingPtpForPool(address _token) external view returns (uint256 pendingPtp);

    function masterPlatypus() external view returns (address);

    function getLPTokensForShares(uint256 amount, address token) external view returns (uint256);

    function getSharesForDepositTokens(uint256 amount, address token) external view returns (uint256);

    function getDepositTokensForShares(uint256 amount, address token) external view returns (uint256);

    function registerPool(
        uint256 _pid,
        address _token,
        address _lpAddress,
        string memory receiptName,
        string memory receiptSymbol,
        uint256 allocpoints
    ) external;

    function getPoolInfo(address _address)
        external
        view
        returns (
            uint256 pid,
            bool isActive,
            address token,
            address lp,
            uint256 sizeLp,
            address receipt,
            uint256 size,
            address rewards_addr,
            address helper
        );

    function removePool(address token) external;

    function nextImplementation() external view returns (address);

    function timelockLength() external view returns (uint256);

    function timelockEndForUpgrade() external view returns (uint256);

    function timelockEndForTimelock() external view returns (uint256);
}
