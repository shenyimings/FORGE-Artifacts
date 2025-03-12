// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface ICurvePool {
    function add_liquidity(uint256[] calldata _amounts, uint256 _minMintAmount) external returns (uint256);

    function add_liquidity(
        uint256[] calldata _amounts,
        uint256 _minMintAmount,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity(
        uint256 _burnAmount,
        uint256[] calldata _minAmounts
    ) external returns (uint256[] calldata);

    function remove_liquidity(
        uint256 _burnAmount,
        uint256[] calldata _minAmounts,
        address _receiver
    ) external returns (uint256[] calldata);

    function remove_liquidity_imbalance(uint256[] calldata _amounts, uint256 _maxBurnAmount) external returns (uint256);

    function remove_liquidity_imbalance(
        uint256[] calldata _amounts,
        uint256 _maxBurnAmount,
        address _receiver
    ) external returns (uint256);

    function remove_liquidity_one_coin(
        uint256 _burnAmount,
        int128 _outputIndex,
        uint256 _minReceived
    ) external returns (uint256);

    function remove_liquidity_one_coin(
        uint256 _burnAmount,
        int128 _outputIndex,
        uint256 _minReceived,
        address _receiver
    ) external returns (uint256);

    function exchange(
        int128 _inputIndex,
        int128 _outputIndex,
        uint256 _inputAmount,
        uint256 _minOutputAmount
    ) external returns (uint256);

    function exchange(
        int128 _inputIndex,
        int128 _outputIndex,
        uint256 _inputAmount,
        uint256 _minOutputAmount,
        address _receiver
    ) external returns (uint256);

    function coins(uint256 _tokenIndex) external view returns (address);

    function admin_balances(uint256 _tokenIndex) external view returns (uint256);

    function fee() external view returns (uint256);

    function initial_A() external view returns (uint256);

    function future_A() external view returns (uint256);

    function initial_A_time() external view returns (uint256);

    function future_A_time() external view returns (uint256);

    function admin_fee() external view returns (uint256);

    function A() external view returns (uint256);

    function A_precise() external view returns (uint256);

    function get_virtual_price() external view returns (uint256);

    function get_balances() external view returns (uint256[] calldata);

    function balances(uint256 _tokenIndex) external view returns (uint256);

    function calc_token_amount(uint256[] calldata _amounts, bool _isDeposit) external view returns (uint256);

    function get_dy(int128 _i, int128 _j, uint256 _dx) external view returns (uint256);

    function calc_withdraw_one_coin(uint256 _burnAmount, int128 _outputIndex) external view returns (uint256);
}
