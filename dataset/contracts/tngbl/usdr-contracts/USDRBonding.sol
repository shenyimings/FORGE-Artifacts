// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./constants/addresses.sol";
import "./constants/roles.sol";
import "./interfaces/IPriceOracle.sol";
import "./AddressAccessor.sol";

bytes32 constant USDR_BONDING_ADDRESS = bytes32(keccak256("USDRBonding"));

interface IExchange {
    function scaleFromUnderlying(uint256 amount)
        external
        view
        returns (uint256);

    function swapFromUnderlying(uint256 amountIn, address to)
        external
        returns (uint256 amountOut);

    function swapFromTNGBL(
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external returns (uint256 amountOut);
}

contract BondingVault {
    address private immutable _owner;

    constructor() {
        _owner = msg.sender;
    }

    function withdraw(
        address token,
        uint256 amount,
        address receiver
    ) external {
        require(_owner == msg.sender);
        IERC20(token).transfer(receiver, amount);
    }

    function sweep(address token) external returns (uint256 amount) {
        require(_owner == msg.sender);
        amount = IERC20(token).balanceOf(address(this));
        if (amount > 0) {
            IERC20(token).transfer(_owner, amount);
        }
    }
}

contract USDRBonding is AddressAccessor {
    uint16 public percentage; // 100 = 1%
    uint256 public available;
    uint256 public lastUpdate;

    uint256 private immutable _resetInterval;

    mapping(address => mapping(address => BondingVault)) private _vaults;

    constructor(uint256 resetInterval) {
        _resetInterval = resetInterval;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function sweepVault(address token, address onBehalfOf)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        BondingVault vault = _vaults[msg.sender][onBehalfOf];
        if (address(vault) != address(0)) {
            _vaults[msg.sender][onBehalfOf].sweep(token);
        }
    }

    function mint(
        uint256 deposit,
        uint256 amountToMint,
        address onBehalfOf
    ) external onlyRole(CONTROLLER_ROLE) returns (uint256 minted) {
        address vault = address(_vaults[msg.sender][onBehalfOf]);
        if (vault == address(0)) {
            vault = address(
                _vaults[msg.sender][onBehalfOf] = new BondingVault()
            );
        }
        available -= deposit;
        (
            address underlying,
            address usdr,
            address exchange,
            address tngbl,
            address tngblOracle
        ) = abi.decode(
                addressProvider.getAddresses(
                    abi.encode(
                        UNDERLYING_ADDRESS,
                        USDR_ADDRESS,
                        USDR_EXCHANGE_ADDRESS,
                        TNGBL_ADDRESS,
                        TNGBL_ORACLE_ADDRESS
                    )
                ),
                (address, address, address, address, address)
            );
        IERC20(underlying).transferFrom(onBehalfOf, address(this), deposit);
        IERC20(underlying).approve(exchange, deposit);
        minted = IExchange(exchange).swapFromUnderlying(deposit, vault);
        amountToMint -= minted;
        uint256 excessUSDR = IERC20(usdr).balanceOf(address(this));
        if (excessUSDR > 0) {
            if (excessUSDR < amountToMint) {
                minted += excessUSDR;
                amountToMint -= excessUSDR;
                IERC20(usdr).transfer(vault, excessUSDR);
            } else {
                minted += amountToMint;
                IERC20(usdr).transfer(vault, amountToMint);
                amountToMint = 0;
            }
        }
        if (amountToMint > 0) {
            uint256 tngblAmount = (amountToMint *
                (10**((IERC20Metadata(tngbl).decimals() << 1) - 9))) /
                IPriceOracle(tngblOracle).quote(1e18) +
                1;
            IERC20(tngbl).approve(exchange, tngblAmount);
            minted += IExchange(exchange).swapFromTNGBL(
                tngblAmount,
                amountToMint,
                vault
            );
        }
    }

    function recoverLostTokens(address token)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(msg.sender, balance);
    }

    function reset(uint256 amount) external onlyRole(CONTROLLER_ROLE) {
        uint256 timestamp = block.timestamp / _resetInterval;
        require(timestamp > lastUpdate, "too early");
        lastUpdate = timestamp;
        available = amount;
    }

    function setPercentage(uint16 value) external onlyRole(DEFAULT_ADMIN_ROLE) {
        percentage = value;
    }

    function withdraw(uint256 amount, address receiver)
        external
        onlyRole(CONTROLLER_ROLE)
    {
        address usdr = addressProvider.getAddress(USDR_ADDRESS);
        BondingVault(_vaults[msg.sender][receiver]).withdraw(
            usdr,
            amount,
            receiver
        );
    }
}
