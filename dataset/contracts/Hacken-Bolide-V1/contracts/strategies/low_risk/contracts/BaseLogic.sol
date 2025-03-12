// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;
pragma abicoder v2;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "./utils/UpgradeableBase.sol";
import "./interfaces/ISwap.sol";
import "./interfaces/IMultiLogicProxy.sol";
import "./interfaces/ILogicContract.sol";

abstract contract BaseLogic is ILogic, UpgradeableBase {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address internal constant ZERO_ADDRESS = address(0);
    address public multiLogicProxy;
    address internal blid;
    address public swapGateway;
    address internal expenseAddress;

    event SetBLID(address _blid);
    event SetExpenseAddress(address expenseAddress);
    event SetSwapGateway(address swapGateway);
    event SetMultiLogicProxy(address multiLogicProxy);

    receive() external payable {}

    fallback() external payable {}

    modifier onlyMultiLogicProxy() {
        require(msg.sender == multiLogicProxy, "E14");
        _;
    }

    /*** Owner function ***/

    /**
     * @notice Set expenseAddress
     * @param _expenseAddress Address of Expense Account
     */
    function setExpenseAddress(address _expenseAddress) external onlyOwner {
        require(_expenseAddress != ZERO_ADDRESS, "E20");

        expenseAddress = _expenseAddress;
        emit SetExpenseAddress(_expenseAddress);
    }

    /**
     * @notice Set swapGateway
     * @param _swapGateway Address of SwapGateway
     */
    function setSwapGateway(address _swapGateway) external onlyOwner {
        require(_swapGateway != ZERO_ADDRESS, "E20");

        swapGateway = _swapGateway;
        emit SetSwapGateway(_swapGateway);
    }

    /**
     * @notice Set blid in contract and approve blid for storage, venus, pancakeswap/apeswap/biswap
     * router, and pancakeswap/apeswap/biswap master(Main Staking contract), you can call the
     * function once
     * @param blid_ Address of BLID
     */
    function setBLID(address blid_) external onlyOwner {
        require(blid_ != ZERO_ADDRESS, "E20");

        blid = blid_;
        IERC20Upgradeable(blid).safeApprove(multiLogicProxy, type(uint256).max);
        emit SetBLID(blid_);
    }

    /**
     * @notice Set MultiLogicProxy, you can call the function once
     * @param _multiLogicProxy Address of Storage Contract
     */
    function setMultiLogicProxy(address _multiLogicProxy) external onlyOwner {
        require(_multiLogicProxy != ZERO_ADDRESS, "E20");

        multiLogicProxy = _multiLogicProxy;

        emit SetMultiLogicProxy(_multiLogicProxy);
    }

    /*** Logic function ***/

    /**
     * @notice Transfer amount of token from Storage to Logic contract token - address of the token
     * @param amount Amount of token
     * @param token Address of token
     */
    function takeTokenFromStorage(uint256 amount, address token)
        external
        override
        onlyOwnerAndAdmin
    {
        IMultiLogicProxy(multiLogicProxy).takeToken(amount, token);
        if (token == ZERO_ADDRESS) {
            require(address(this).balance >= amount, "E16");
        }
    }

    /**
     * @notice Transfer amount of token from Logic to Storage contract token - address of token
     * @param amount Amount of token
     * @param token Address of token
     */
    function returnTokenToStorage(uint256 amount, address token)
        external
        override
        onlyOwnerAndAdmin
    {
        if (token == ZERO_ADDRESS) {
            _send(payable(multiLogicProxy), amount);
        }

        IMultiLogicProxy(multiLogicProxy).returnToken(amount, token);
    }

    /**
     * @notice Transfer amount of ETH from Logic to MultiLogicProxy
     * @param amount Amount of ETH
     */
    function returnETHToMultiLogicProxy(uint256 amount)
        external
        override
        onlyOwnerAndAdmin
    {
        _send(payable(multiLogicProxy), amount);
    }

    /**
     * @notice Distribution amount of blid to depositors.
     * @param amount Amount of BLID
     */
    function addEarnToStorage(uint256 amount)
        external
        override
        onlyOwnerAndAdmin
    {
        IERC20Upgradeable(blid).safeTransfer(
            expenseAddress,
            (amount * 3) / 100
        );
        IMultiLogicProxy(multiLogicProxy).addEarn(
            amount - ((amount * 3) / 100),
            blid
        );
    }

    /**
     * @notice Approve swap for token
     * @param _swap Address of swapRouter
     * @param token Address of token
     */
    function approveTokenForSwap(address _swap, address token)
        public
        onlyOwnerAndAdmin
    {
        if (IERC20Upgradeable(token).allowance(address(this), _swap) == 0) {
            IERC20Upgradeable(token).safeApprove(_swap, type(uint256).max);
        }
    }

    /*** Swap function ***/

    /**
     * @notice Swap tokens using swapRouter
     * @param swapRouter Address of swapRouter contract
     * @param amountIn Amount for in
     * @param amountOut Amount for out
     * @param path swap path, path[0] is in, path[last] is out
     * @param isExactInput true : swapExactTokensForTokens, false : swapTokensForExactTokens
     * @param deadline Unix timestamp deadline by which the transaction must confirm.
     */
    function swap(
        address swapRouter,
        uint256 amountIn,
        uint256 amountOut,
        address[] memory path,
        bool isExactInput,
        uint256 deadline
    )
        external
        payable
        override
        onlyOwnerAndAdmin
        returns (uint256[] memory amounts)
    {
        if (path[0] == ZERO_ADDRESS) {
            require(address(this).balance >= amountIn, "E18");

            amounts = ISwapGateway(swapGateway).swap{value: amountIn}(
                swapRouter,
                amountIn,
                amountOut,
                path,
                isExactInput,
                deadline
            );
        } else {
            require(
                IERC20Upgradeable(path[0]).balanceOf(address(this)) >= amountIn,
                "E18"
            );
            require(
                IERC20Upgradeable(path[0]).allowance(
                    address(this),
                    swapGateway
                ) >= amountIn,
                "E19"
            );

            amounts = ISwapGateway(swapGateway).swap(
                swapRouter,
                amountIn,
                amountOut,
                path,
                isExactInput,
                deadline
            );
        }
    }

    /*** Private Function ***/

    /**
     * @notice Send ETH to address
     * @param _to target address to receive ETH
     * @param amount ETH amount (wei) to be sent
     */
    function _send(address payable _to, uint256 amount) private {
        (bool sent, ) = _to.call{value: amount}("");
        require(sent, "E17");
    }
}
