pragma solidity 0.8.9;

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {NeuronPoolCommon} from "./NeuronPoolCommon.sol";

abstract contract NeuronPoolBaseInitialize is
    NeuronPoolCommon,
    Initializable,
    ERC20Upgradeable,
    ReentrancyGuardUpgradeable
{
    function __NeuronPoolBaseInitialize_init(
        address _token,
        address _governance,
        address _timelock,
        address _controller
    ) internal initializer {
        __ERC20_init(
            string(abi.encodePacked("neuroned", IERC20Metadata(_token).name())),
            string(abi.encodePacked("neur", IERC20Metadata(_token).symbol()))
        );
        __ReentrancyGuard_init_unchained();

        token = IERC20Metadata(_token);
        tokenDecimals = uint256(token.decimals());
        governance = _governance;
        timelock = _timelock;
        controller = _controller;
        min = 9500;
    }

    function deposit(address _enterToken, uint256 _amount) public payable virtual override nonReentrant returns (uint256) {
        return super.deposit(_enterToken, _amount);
    }

    function withdraw(address _withdrawableToken, uint256 _shares) public virtual override nonReentrant {
        super.withdraw(_withdrawableToken, _shares);
    }

    function balanceOf(address account)
        public
        view
        virtual
        override(ERC20Upgradeable, NeuronPoolCommon)
        returns (uint256)
    {
        return ERC20Upgradeable.balanceOf(account);
    }

    function _burn(address account, uint256 amount) internal override(NeuronPoolCommon, ERC20Upgradeable) {
        ERC20Upgradeable._burn(account, amount);
    }

    function _mint(address account, uint256 amount) internal override(NeuronPoolCommon, ERC20Upgradeable) {
        ERC20Upgradeable._mint(account, amount);
    }

    function decimals() public view override(NeuronPoolCommon, ERC20Upgradeable) returns (uint8) {
        return NeuronPoolCommon.decimals();
    }

    function totalSupply() public view override(NeuronPoolCommon, ERC20Upgradeable) returns (uint256) {
        return ERC20Upgradeable.totalSupply();
    }
}
