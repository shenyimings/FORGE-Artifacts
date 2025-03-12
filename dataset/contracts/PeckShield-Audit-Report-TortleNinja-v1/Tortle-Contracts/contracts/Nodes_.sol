// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract Nodes_ is ReentrancyGuard {
    address public owner;
    IUniswapV2Router02 router; // Router.
    address private FTM;

    struct SplitStruct {
        address user;
        address token;
        uint256 amount;
        address firstToken;
        address secondToken;
        uint256 percentageFirstToken;
        uint256 amountOutMinFirst;
        uint256 amountOutMinSecond;
    }

    constructor(address _owner, address _router) {
        owner = _owner;
        router = IUniswapV2Router02(_router); // TestNet
        FTM = router.WETH();
    }

    /**
     * @notice Calculate the percentage of a number.
     * @param x Number.
     * @param y Percentage of number.
     * @param scale Division.
     */
    function mulScale(
        uint256 x,
        uint256 y,
        uint128 scale
    ) internal pure returns (uint256) {
        uint256 a = x / scale;
        uint256 b = x % scale;
        uint256 c = y / scale;
        uint256 d = y % scale;

        return a * c * scale + a * d + b * c + (b * d) / scale;
    }

    /**
     * @notice Function that divides the token you send into two tokens according to the percentage you select.
     * @param _token Address of the token to be splited.
     * @param _amount Amount of Tokens to be splited.
     * @param _firstToken Contract of the first token you wish to receive.
     * @param _secondToken Contract of the second token you wish to receive.
     * @param _percentageFirstToken Percentage of the split
     * @param _amountOutMinFirst Minimum amount you wish to receive.
     * @param _amountOutMinSecond Minimum amount you wish to receive.
     */
    function split(
        address _token,
        uint256 _amount,
        address _firstToken,
        address _secondToken,
        uint256 _percentageFirstToken,
        uint256 _amountOutMinFirst,
        uint256 _amountOutMinSecond
    )
        public
        nonReentrant
        returns (uint256 amountOutToken1, uint256 amountOutToken2)
    {
        uint256 _firstTokenAmount = mulScale(
            _amount,
            _percentageFirstToken,
            10000
        ); // Amount of first token.
        uint256 _secondTokenAmount = _amount - _firstTokenAmount; // Amount of second token.

        IERC20(_token).approve(address(router), _amount);

        uint256[] memory amountsOut;
        uint256 _amountOutToken1;
        uint256 _amountOutToken2;
        if (_token == FTM) {
            (_amountOutToken1, _amountOutToken2) = _splitFromFTM(
                _firstToken,
                _secondToken,
                _firstTokenAmount,
                _secondTokenAmount,
                _amountOutMinFirst,
                _amountOutMinSecond
            );
        } else if (_firstToken == FTM || _secondToken == FTM) {
            (_amountOutToken1, _amountOutToken2) = _splitToFTM(
                _token,
                _firstToken,
                _secondToken,
                _firstTokenAmount,
                _secondTokenAmount,
                _amountOutMinFirst,
                _amountOutMinSecond
            );
        } else {
            if (_firstToken != _token) {
                address[] memory pathFirstToken = new address[](3);
                pathFirstToken[0] = _token;
                pathFirstToken[1] = FTM;
                pathFirstToken[2] = _firstToken;

                amountsOut = router.swapExactTokensForTokens(
                    _firstTokenAmount,
                    _amountOutMinFirst,
                    pathFirstToken,
                    address(msg.sender),
                    block.timestamp
                );

                _amountOutToken1 = amountsOut[amountsOut.length - 1];
            } else {
                _amountOutToken1 = _firstTokenAmount;
                IERC20(_firstToken).transfer(msg.sender, _firstTokenAmount);
            }

            if (_secondToken != _token) {
                address[] memory pathSecondToken = new address[](3);
                pathSecondToken[0] = _token;
                pathSecondToken[1] = FTM;
                pathSecondToken[2] = _secondToken;

                amountsOut = router.swapExactTokensForTokens(
                    _secondTokenAmount,
                    _amountOutMinSecond,
                    pathSecondToken,
                    address(msg.sender),
                    block.timestamp
                );

                _amountOutToken2 = amountsOut[amountsOut.length - 1];
            } else {
                _amountOutToken2 = _secondTokenAmount;
                IERC20(_secondToken).transfer(msg.sender, _secondTokenAmount);
            }
        }

        return (_amountOutToken1, _amountOutToken2);
    }

    function _splitFromFTM(
        address _firstToken,
        address _secondToken,
        uint256 _firstTokenAmount,
        uint256 _secondTokenAmount,
        uint256 _amountOutMinFirst,
        uint256 _amountOutMinSecond
    ) private returns (uint256 amountOutToken1, uint256 amountOutToken2) {
        uint256[] memory amountsOut;

        uint256 _amountOutToken1;
        if (_firstToken != FTM) {
            address[] memory pathFirstToken = new address[](2);
            pathFirstToken[0] = FTM;
            pathFirstToken[1] = _firstToken;

            amountsOut = router.swapExactTokensForTokens(
                _firstTokenAmount,
                _amountOutMinFirst,
                pathFirstToken,
                address(msg.sender),
                block.timestamp
            );

            _amountOutToken1 = amountsOut[amountsOut.length - 1];
        } else {
            _amountOutToken1 = _firstTokenAmount;
            IERC20(_firstToken).transfer(msg.sender, _firstTokenAmount);
        }

        uint256 _amountOutToken2;
        if (_secondToken != FTM) {
            address[] memory pathSecondToken = new address[](2);
            pathSecondToken[0] = FTM;
            pathSecondToken[1] = _secondToken;

            amountsOut = router.swapExactTokensForTokens(
                _secondTokenAmount,
                _amountOutMinSecond,
                pathSecondToken,
                address(msg.sender),
                block.timestamp
            );

            _amountOutToken2 = amountsOut[amountsOut.length - 1];
        } else {
            _amountOutToken2 = _secondTokenAmount;
            IERC20(_secondToken).transfer(msg.sender, _secondTokenAmount);
        }

        return (_amountOutToken1, _amountOutToken2);
    }

    function _splitToFTM(
        address _token,
        address _firstToken,
        address _secondToken,
        uint256 _firstTokenAmount,
        uint256 _secondTokenAmount,
        uint256 _amountOutMinFirst,
        uint256 _amountOutMinSecond
    ) private returns (uint256 amountOutToken1, uint256 amountOutToken2) {
        uint256[] memory amountsOut;
        uint256 _amountOutToken1;
        uint256 _amountOutToken2;
        if (_firstToken == FTM) {
            if (_firstToken != _token) {
                address[] memory pathFirstToken = new address[](2);
                pathFirstToken[0] = address(_token);
                pathFirstToken[1] = FTM;

                amountsOut = router.swapExactTokensForTokens(
                    _firstTokenAmount,
                    _amountOutMinFirst,
                    pathFirstToken,
                    address(msg.sender),
                    block.timestamp
                );

                _amountOutToken1 = amountsOut[amountsOut.length - 1];
            } else {
                _amountOutToken1 = _firstTokenAmount;
                IERC20(_firstToken).transfer(msg.sender, _firstTokenAmount);
            }

            if (_secondToken != _token) {
                address[] memory pathSecondToken = new address[](3);
                pathSecondToken[0] = address(_token);
                pathSecondToken[1] = FTM;
                pathSecondToken[2] = _secondToken;

                amountsOut = router.swapExactTokensForTokens(
                    _secondTokenAmount,
                    _amountOutMinSecond,
                    pathSecondToken,
                    address(msg.sender),
                    block.timestamp
                );

                _amountOutToken2 = amountsOut[amountsOut.length - 1];
            } else {
                _amountOutToken2 = _secondTokenAmount;
                IERC20(_secondToken).transfer(msg.sender, _secondTokenAmount);
            }
        } else if (_secondToken == FTM) {
            if (_firstToken != _token) {
                address[] memory pathFirstToken = new address[](3);
                pathFirstToken[0] = address(_token);
                pathFirstToken[1] = FTM;
                pathFirstToken[2] = _firstToken;

                amountsOut = router.swapExactTokensForTokens(
                    _firstTokenAmount,
                    _amountOutMinFirst,
                    pathFirstToken,
                    address(msg.sender),
                    block.timestamp
                );

                _amountOutToken1 = amountsOut[amountsOut.length - 1];
            } else {
                _amountOutToken1 = _firstTokenAmount;
                IERC20(_firstToken).transfer(msg.sender, _firstTokenAmount);
            }

            if (_secondToken != _token) {
                address[] memory pathSecondToken = new address[](2);
                pathSecondToken[0] = address(_token);
                pathSecondToken[1] = FTM;

                amountsOut = router.swapExactTokensForTokens(
                    _secondTokenAmount,
                    _amountOutMinSecond,
                    pathSecondToken,
                    address(msg.sender),
                    block.timestamp
                );

                _amountOutToken2 = amountsOut[amountsOut.length - 1];
            } else {
                _amountOutToken2 = _secondTokenAmount;
                IERC20(_secondToken).transfer(msg.sender, _secondTokenAmount);
            }
        }

        return (_amountOutToken1, _amountOutToken2);
    }

    /**
     * @notice Function that allows to send X amount of tokens and returns the token you want.
     * @param _token Address of the token to be swapped.
     * @param _amount Amount of Tokens to be swapped.
     * @param _newToken Contract of the token you wish to receive.
     * @param _amountOutMin Minimum amount you wish to receive.
     */
    function swapTokens(
        IERC20 _token,
        uint256 _amount,
        address _newToken,
        uint256 _amountOutMin
    ) public nonReentrant returns (uint256 amountOut) {
        _token.approve(address(router), _amount);

        uint256[] memory amountsOut;
        uint256 _amountOut;
        if (address(_token) == FTM || _newToken == FTM) {
            address[] memory path = new address[](2);
            path[0] = address(_token);
            path[1] = _newToken;

            amountsOut = router.swapExactTokensForTokens(
                _amount,
                _amountOutMin,
                path,
                address(msg.sender),
                block.timestamp
            );

            _amountOut = amountsOut[amountsOut.length - 1];
        } else {
            address[] memory path = new address[](3);
            path[0] = address(_token);
            path[1] = FTM;
            path[2] = _newToken;

            amountsOut = router.swapExactTokensForTokens(
                _amount,
                _amountOutMin,
                path,
                address(msg.sender),
                block.timestamp
            );

            _amountOut = amountsOut[amountsOut.length - 1];
        }

        return _amountOut;
    }

    receive() external payable {}
}
