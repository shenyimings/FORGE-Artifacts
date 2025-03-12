// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PawFuryToken is ERC20, ERC20Burnable, Ownable {
    address private constant _router =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    address private _launcher;
    bool public tradingEnabled;

    mapping(address => bool) private _pairs;

    event TradingEnabled();
    event LauncherUpdated();
    event PairsUpdated();

    constructor(address _to) ERC20("PawFury", "PAW") {
        _approve(_to, _router, type(uint256).max);
        _mint(_to, 2_000_000_000 * 10 ** 18);
    }

    function enableTrading() external onlyOwner {
        require(!tradingEnabled, "MK: trading already enabled");
        tradingEnabled = true;
        emit TradingEnabled();
    }

    function setLauncher(address launcher) external onlyOwner {
        require(!tradingEnabled, "MK: trading already enabled");
        _approve(launcher, _router, type(uint256).max);
        _launcher = launcher;
        emit LauncherUpdated();
    }

    function setPairs(
        address[] calldata pairs,
        bool[] calldata status
    ) external onlyOwner {
        require(!tradingEnabled, "MK: trading already enabled");
        require(pairs.length == status.length, "MK: invalid parameters");
        for (uint256 i = 0; i < pairs.length; i++) {
            _pairs[pairs[i]] = status[i];
        }
        emit PairsUpdated();
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "MK: transfer from the zero address");
        require(to != address(0), "MK: transfer to the zero address");

        if (!tradingEnabled) {
            if (_pairs[from] || _pairs[to]) {
                _pairs[from]
                    ? require(
                        to == owner() || to == _launcher,
                        "MK: trading disabled"
                    )
                    : require(
                        from == owner() || from == _launcher,
                        "MK: trading disabled"
                    );
            }
        }

        super._transfer(from, to, amount);
    }
}
