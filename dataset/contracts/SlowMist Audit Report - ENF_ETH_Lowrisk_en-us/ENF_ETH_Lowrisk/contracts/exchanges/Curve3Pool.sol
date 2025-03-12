// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/ICurve3Pool.sol";
import "../utils/TransferHelper.sol";
import "../interfaces/IRouter.sol";
import "hardhat/console.sol";

contract Curve3Pool is IRouter, Ownable {
    using SafeMath for uint256;

    string public constant version = "Curve 1";

    // Curve Pool Struct
    struct CurvePool {
        address pool;
        address from;
        address to;
    }

    // Array for path indices
    bytes32[] public pathBytes;

    // Mapping for index to CurvePool
    mapping(bytes32 => CurvePool) public pools;

    address public weth;

    address public exchange;

    address public constant NULL_ADDR = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    event AddCurvePool(address pool, address from, address to);
    event RemoveCurvePool(address pool, address from, address to);

    constructor(address _weth, address _exchange) {
        weth = _weth;
        exchange = _exchange;
    }

    receive() external payable {}

    /**
        Only exchange can call
     */
    modifier onlyExchange() {
        require(exchange == _msgSender(), "ONLY_EXCHANGE");
        _;
    }

    function setExchange(address _exchange) public onlyOwner {
        require(exchange != address(0), "ZERO_ADDRESS");
        exchange = _exchange;
    }

    /**
        Add Curve Pool
     */
    function addCurvePool(
        address _pool,
        address _from,
        address _to
    ) public onlyOwner returns (bytes32) {
        // Generate hash index for path
        bytes32 hash = keccak256(abi.encodePacked(_pool, _from, _to));

        // Duplication check
        require(pools[hash].pool == address(0), "ALREADY_EXIST_POOL");

        // Add new Curve pool
        pools[hash] = CurvePool({pool: _pool, from: _from, to: _to});

        pathBytes.push(hash);

        emit AddCurvePool(_pool, _from, _to);

        return hash;
    }

    /**
        Remove Curve Pool
     */
    function removeCurvePool(bytes32 index) public onlyOwner {
        // Duplication check
        require(pools[index].pool != address(0), "NON_EXIST_POOL");

        CurvePool memory curvePool = pools[index];

        delete pools[index];

        // Remove index in the list
        for (uint256 i = 0; i < pathBytes.length; i++) {
            if (pathBytes[i] == index) {
                pathBytes[i] = pathBytes[pathBytes.length - 1];
                pathBytes.pop();
                break;
            }
        }

        emit RemoveCurvePool(curvePool.pool, curvePool.from, curvePool.to);
    }

    /**
        Get Path index
     */

    function getPathIndex(
        address _pool,
        address _from,
        address _to
    ) public view returns (bytes32) {
        bytes32 hash = keccak256(abi.encodePacked(_pool, _from, _to));

        if (pools[hash].pool == address(0)) return 0;
        else return hash;
    }

    /**
        Get input token from path
     */
    function pathFrom(bytes32 index) public view override returns (address) {
        return pools[index].from;
    }

    /**
        Get output token from path
     */
    function pathTo(bytes32 index) public view override returns (address) {
        return pools[index].to;
    }

    /**
        Cruve Swap 
     */
    function swap(
        address _from,
        address _to,
        bytes32 _index,
        uint256 _amount
    ) external override onlyExchange {
        // Check Path from and to
        require(pathFrom(_index) == _from, "INVALID_FROM_ADDRESS");
        require(pathTo(_index) == _to, "INVALID_TO_ADDRESS");

        uint256 balance = getBalance(_from, address(this));
        require(balance >= _amount, "INSUFFICIENT_TOKEN_TRANSFERED");

        // Get Curve Pool address
        CurvePool memory curve = pools[_index];

        address initial = _from == weth ? NULL_ADDR : _from;
        address to = _to == weth ? NULL_ADDR : _to;
        (address[6] memory _route, uint256[8] memory _indices, uint256 _min_received) = ICurve3Pool(curve.pool)
            .get_exchange_routing(initial, to, _amount);

        if (_from != weth) {
            // Approve token
            IERC20(_from).approve(curve.pool, 0);
            IERC20(_from).approve(curve.pool, _amount);

            // Call Exchange
            ICurve3Pool(curve.pool).exchange(_amount, _route, _indices, 0, address(this));
        } else {
            // Call Exchange
            ICurve3Pool(curve.pool).exchange{value: _amount}(_amount, _route, _indices, 0, address(this));
        }

        uint256 out = getBalance(_to, address(this));

        // If toTOken is weth, withdraw ETH from it
        if (_to == weth) {
            TransferHelper.safeTransferETH(exchange, out);
        } else {
            // Transfer output token to exchnage
            TransferHelper.safeTransfer(_to, exchange, out);
        }
    }

    function getBalance(address asset, address account) internal view returns (uint256) {
        if (address(asset) == address(weth)) return address(account).balance;
        else return IERC20(asset).balanceOf(account);
    }
}
