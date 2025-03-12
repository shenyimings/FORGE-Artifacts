pragma solidity 0.8.9;

import {ERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {NeuronPoolCommon} from "./NeuronPoolCommon.sol";

abstract contract NeuronPoolBase is NeuronPoolCommon, ERC20, ReentrancyGuard {
    constructor(
        address _token,
        address _governance,
        address _timelock,
        address _controller
    )
        ERC20(
            string(abi.encodePacked("neuroned", IERC20Metadata(_token).name())),
            string(abi.encodePacked("neur", IERC20Metadata(_token).symbol()))
        )
    {
        token = IERC20Metadata(_token);
        tokenDecimals = uint256(token.decimals());
        governance = _governance;
        timelock = _timelock;
        controller = _controller;
    }

    function deposit(address _enterToken, uint256 _amount) public payable virtual override nonReentrant returns (uint256) {
        return super.deposit(_enterToken, _amount);
    }

    function withdraw(address _withdrawableToken, uint256 _shares) public virtual override nonReentrant {
        super.withdraw(_withdrawableToken, _shares);
    }

    function balanceOf(address account) public view virtual override(ERC20, NeuronPoolCommon) returns (uint256) {
        return ERC20.balanceOf(account);
    }

    function _burn(address account, uint256 amount) internal override(NeuronPoolCommon, ERC20) {
        ERC20._burn(account, amount);
    }

    function _mint(address account, uint256 amount) internal override(NeuronPoolCommon, ERC20) {
        ERC20._mint(account, amount);
    }

    function decimals() public view override(NeuronPoolCommon, ERC20) returns (uint8) {
        return NeuronPoolCommon.decimals();
    }

    function totalSupply() public view override(NeuronPoolCommon, ERC20) returns (uint256) {
        return ERC20.totalSupply();
    }
}
