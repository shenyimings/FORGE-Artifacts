// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.7.6;
pragma experimental ABIEncoderV2;

import "../interfaces/compound/IComptroller.sol";
import "../interfaces/compound/ICompErc20.sol";
import "./BaseLending.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@kyber.network/utils-sc/contracts/IERC20Ext.sol";

contract CompoundLending is BaseLending {
    using SafeERC20 for IERC20Ext;
    using SafeMath for uint256;

    struct CompoundData {
        address comptroller;
        mapping(IERC20Ext => address) cTokens;
    }

    CompoundData public compoundData;

    constructor(address _admin) BaseLending(_admin) {}

    function updateCompoundData(
        address _comptroller,
        address _cEth,
        address[] calldata _cTokens
    ) external onlyAdmin {
        require(_comptroller != address(0), "invalid _comptroller");
        require(_cEth != address(0), "invalid cEth");

        if (compoundData.comptroller != _comptroller) {
            compoundData.comptroller = _comptroller;
        }

        if (compoundData.cTokens[ETH_TOKEN_ADDRESS] != _cEth) {
            compoundData.cTokens[ETH_TOKEN_ADDRESS] = _cEth;
        }

        IERC20Ext[] memory tokens;
        if (_cTokens.length > 0) {
            // add specific markets
            tokens = new IERC20Ext[](_cTokens.length);
            for (uint256 i = 0; i < _cTokens.length; i++) {
                require(_cTokens[i] != address(0), "invalid cToken");
                tokens[i] = IERC20Ext(ICompErc20(_cTokens[i]).underlying());
                require(tokens[i] != IERC20Ext(0), "invalid underlying token");

                if (compoundData.cTokens[tokens[i]] != _cTokens[i]) {
                    compoundData.cTokens[tokens[i]] = _cTokens[i];
                    safeApproveAllowance(_cTokens[i], tokens[i]);
                }
            }
        } else {
            // add all markets
            ICompErc20[] memory markets = IComptroller(_comptroller).getAllMarkets();
            tokens = new IERC20Ext[](markets.length);
            address[] memory cTokens = new address[](markets.length);
            for (uint256 i = 0; i < markets.length; i++) {
                if (address(markets[i]) == _cEth) {
                    tokens[i] = ETH_TOKEN_ADDRESS;
                    cTokens[i] = _cEth;
                    continue;
                }
                require(markets[i] != ICompErc20(0), "invalid cToken");
                tokens[i] = IERC20Ext(markets[i].underlying());
                require(tokens[i] != IERC20Ext(0), "invalid underlying token");
                cTokens[i] = address(markets[i]);

                if (compoundData.cTokens[tokens[i]] != cTokens[i]) {
                    compoundData.cTokens[tokens[i]] = cTokens[i];
                    safeApproveAllowance(cTokens[i], tokens[i]);
                }
            }
        }
    }

    /// @dev deposit to lending platforms
    ///     expect amount of token should already be in the contract
    function depositTo(
        address payable onBehalfOf,
        IERC20Ext token,
        uint256 amount
    ) external override onlyProxyContract {
        require(getBalance(token, address(this)) >= amount, "low balance");
        // Compound
        address cToken = compoundData.cTokens[token];
        require(cToken != address(0), "token is not supported by Compound");
        uint256 cTokenBalanceBefore = IERC20Ext(cToken).balanceOf(address(this));
        if (token == ETH_TOKEN_ADDRESS) {
            ICompEth(cToken).mint{value: amount}();
        } else {
            require(ICompErc20(cToken).mint(amount) == 0, "can not mint cToken");
        }
        uint256 cTokenBalanceAfter = IERC20Ext(cToken).balanceOf(address(this));
        IERC20Ext(cToken).safeTransfer(onBehalfOf, cTokenBalanceAfter.sub(cTokenBalanceBefore));
    }

    /// @dev withdraw from lending platforms
    ///     expect amount of aToken or cToken should already be in the contract
    function withdrawFrom(
        address payable onBehalfOf,
        IERC20Ext token,
        uint256 amount,
        uint256 minReturn
    ) external override onlyProxyContract returns (uint256 returnedAmount) {
        address lendingToken = getLendingToken(token);
        uint256 tokenBalanceBefore = getBalance(token, address(this));

        // burn cToken to withdraw underlying token
        require(ICompErc20(lendingToken).redeem(amount) == 0, "unable to redeem");

        returnedAmount = getBalance(token, address(this)).sub(tokenBalanceBefore);
        require(returnedAmount >= minReturn, "low returned amount");

        // transfer underlying token to user
        transferToken(onBehalfOf, token, returnedAmount);
    }

    /// @dev repay borrows to lending platforms
    ///     expect amount of token should already be in the contract
    ///     if amount > payAmount, (amount - payAmount) will be sent back to user
    function repayBorrowTo(
        address payable onBehalfOf,
        IERC20Ext token,
        uint256 amount,
        uint256 payAmount,
        bytes calldata extraArgs
    ) external override onlyProxyContract {
        require(amount >= payAmount, "invalid pay amount");
        require(getBalance(token, address(this)) >= amount, "bad token balance");

        if (amount > payAmount) {
            // transfer back token
            transferToken(payable(onBehalfOf), token, amount - payAmount);
        }

        address cToken = compoundData.cTokens[token];
        require(cToken != address(0), "token is not supported by Compound");
        if (token == ETH_TOKEN_ADDRESS) {
            ICompEth(cToken).repayBorrowBehalf{value: payAmount}(onBehalfOf);
        } else {
            require(
                ICompErc20(cToken).repayBorrowBehalf(onBehalfOf, payAmount) == 0,
                "compound repay error"
            );
        }
    }

    /// @dev just a convenient method to claim Comp, user can call this contract directly
    function claimComp(
        address[] calldata holders,
        ICompErc20[] calldata cTokens,
        bool borrowers,
        bool suppliers
    ) external {
        require(holders.length > 0, "no holders");
        IComptroller comptroller = IComptroller(compoundData.comptroller);
        if (cTokens.length == 0) {
            // claim for all markets
            ICompErc20[] memory markets = comptroller.getAllMarkets();
            comptroller.claimComp(holders, markets, borrowers, suppliers);
        } else {
            comptroller.claimComp(holders, cTokens, borrowers, suppliers);
        }
    }

    function getLendingToken(IERC20Ext token) public view override returns (address) {
        return compoundData.cTokens[token];
    }

    /** @dev Calculate the current user debt and return */
    function getUserDebtCurrent(address _reserve, address _user)
        external
        override
        returns (uint256 debt)
    {
        ICompErc20 cToken = ICompErc20(compoundData.cTokens[IERC20Ext(_reserve)]);
        debt = cToken.borrowBalanceCurrent(_user);
    }
}
