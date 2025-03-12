// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {IARTH} from './IARTH.sol';
import {IIncentiveController} from './IIncentive.sol';
import {AnyswapV4Token} from '../ERC20/AnyswapV4Token.sol';

/**
 * @title  ARTHStablecoin.
 * @author MahaDAO.
 */
contract ARTHStablecoin is AnyswapV4Token, IARTH {
    IIncentiveController public incentiveController;
    address public governance;

    uint8 public constant override decimals = 18;
    string public constant symbol = 'ARTH';
    string public constant name = 'ARTH Valuecoin';

    /// @notice This is to help with establishing the Uniswap pools, as they need liquidity.
    uint256 public constant override genesisSupply = 22000000e18; // 22M ARTH (testnet) & 5k (Mainnet).

    mapping(address => bool) public pools;

    event PoolBurned(address indexed from, address indexed to, uint256 amount);
    event PoolMinted(address indexed from, address indexed to, uint256 amount);

    modifier onlyPools() {
        require(pools[msg.sender] == true, 'ARTH: not pool');
        _;
    }

    modifier onlyByOwnerOrGovernance() {
        require(
            msg.sender == owner() || msg.sender == governance,
            'ARTH: not owner or governance'
        );
        _;
    }

    constructor() AnyswapV4Token(name) {
        _mint(msg.sender, genesisSupply);
    }

    /// @notice Used by pools when user redeems.
    function poolBurnFrom(address who, uint256 amount)
        external
        override
        onlyPools
    {
        super._burnFrom(who, amount);
        emit PoolBurned(who, msg.sender, amount);
    }

    /// @notice This function is what other arth pools will call to mint new ARTH
    function poolMint(address who, uint256 amount) external override onlyPools {
        super._mint(who, amount);
        emit PoolMinted(msg.sender, who, amount);
    }

    /// @dev    Collateral Must be ERC20.
    /// @notice Adds collateral addresses supported.
    function addPool(address pool) external override onlyByOwnerOrGovernance {
        require(pools[pool] == false, 'pool exists');
        pools[pool] = true;
    }

    /// @notice Removes a pool.
    function removePool(address pool)
        external
        override
        onlyByOwnerOrGovernance
    {
        require(pools[pool] == true, "pool doesn't exist");
        delete pools[pool];
    }

    function setGovernance(address _governance) external override onlyOwner {
        governance = _governance;
    }

    function setIncentiveController(IIncentiveController _incentiveController)
        external
        override
        onlyByOwnerOrGovernance
    {
        incentiveController = _incentiveController;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal override {
        super._transfer(sender, recipient, amount);
        if (address(incentiveController) != address(0)) {
            incentiveController.incentivize(
                sender,
                recipient,
                msg.sender,
                amount
            );
        }
    }
}
