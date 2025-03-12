// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@amxx/hre/contracts/ENSReverseRegistration.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "../amm/libraries/UniswapV2Library.sol";

/**
 * @dev Liquidates and redistributes AMM fees for the p00ls <> eth and p00ls <> creatorToken pairs.
 * On liquidation, the raised amounts to the recipient, which is expected to be a ERC4626 like vault or an ERC20
 * supporting payment splitter. It could also be a governance contract.
 *
 * - In the case of p00ls <> eth, all the liquidated values goes to the recipient.
 * - In the case of p00ls <> creatorToken, half of the liquidated values goes to the token owner, and the rest goes to
 *   the recipient.
 *
 * @notice Setting the recipient to address(0) will temporarily disable any fee redistribution. This can be reverted
 * by updating the recipient to a non zero address.
 */
/// @custom:security-contact security@p00ls.com
contract FeeManager is AccessControl, Multicall {
    bytes32 public constant REDISTRIBUTION_MANAGER_ROLE = keccak256("REDISTRIBUTION_MANAGER_ROLE");

    IUniswapV2Router02 public immutable router;
    IUniswapV2Factory  public immutable factory;
    IERC20             public immutable p00ls;
    address            public           recipient;
    uint256            public           fee;

    event FeesToOwner(address indexed owner, uint256 amount);
    event FeesToRecipient(address indexed recipient, uint256 amount);
    event FeesLiquidated(address indexed token, uint256 liquidity, uint256 amount);
    event RecipientUpdated(address recipient);
    event FeeUpdated(uint256 fee);

    constructor(address _admin, IUniswapV2Router02 _router, IERC20 _p00ls, address _recipient, uint256 _fee)
    {
        require(_fee <= 1e18, "Invalid fee amount");

        _grantRole(DEFAULT_ADMIN_ROLE,          _admin);
        _grantRole(REDISTRIBUTION_MANAGER_ROLE, _admin);

        router    = _router;
        factory   = IUniswapV2Factory(_router.factory());
        p00ls     = _p00ls;
        recipient = _recipient; // by default this should be the xP00ls
        fee       = _fee;

        emit FeeUpdated(_fee);
        emit RecipientUpdated(_recipient);
    }

    // token is crea or weth
    function redistributedFees(IERC20 token)
        external
        onlyRole(REDISTRIBUTION_MANAGER_ROLE)
    {
        uint256 profit = _liquidateAllLP(token);

        // WETH has no owner, creator tokens do.
        try Ownable(address(token)).owner() returns (address owner) {
            if (owner != address(0)) { // just to be safe
                uint256 ownerShare = profit * fee / 1e18;
                SafeERC20.safeTransfer(p00ls, owner, ownerShare);
                emit FeesToOwner(owner, ownerShare);
            }
        } catch {}

        // there might be more because of a transfer, we send it to the recipient
        uint256 amount = p00ls.balanceOf(address(this));
        SafeERC20.safeTransfer(p00ls, recipient, amount);
        emit FeesToRecipient(recipient, amount);
    }

    function _liquidateAllLP(IERC20 token) private returns (uint256) {
        // find pair
        IERC20 pair = IERC20(UniswapV2Library.pairFor(address(factory), address(p00ls), address(token)));

        // liquidate all lps
        uint256 liquidity  = pair.balanceOf(address(this));
        SafeERC20.safeApprove(pair, address(router), liquidity);
        (uint256 amountToken, uint256 amountP00ls) = router.removeLiquidity(address(token), address(p00ls), liquidity, 0, 0, address(this), block.timestamp);

        // Swap tokens from token to p00ls
        SafeERC20.safeApprove(token, address(router), amountToken);
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = address(p00ls);
        uint256[] memory amounts = router.swapExactTokensForTokens(amountToken, 0, path, address(this), block.timestamp);
        amountP00ls += amounts[1];

        emit FeesLiquidated(address(token), liquidity, amountP00ls);

        return amountP00ls;
    }

    function setRecipient(address newRecipient)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        emit RecipientUpdated(newRecipient);
        recipient = newRecipient;
    }

    function setFee(uint256 newFee)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(newFee <= 1e18, "Invalid fee amount");
        emit FeeUpdated(newFee);
        fee = newFee;
    }

    function setName(address ensregistry, string calldata ensname)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        ENSReverseRegistration.setName(ensregistry, ensname);
    }
}
