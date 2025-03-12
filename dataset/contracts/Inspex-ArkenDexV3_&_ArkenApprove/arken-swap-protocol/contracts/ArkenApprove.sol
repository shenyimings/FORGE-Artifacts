// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/proxy/utils/Initializable.sol';
// import 'hardhat/console.sol';
import './lib/OwnableUpgradeable.sol';

contract ArkenApprove is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    /* ArkenDexV2 Proxy Storage: start */
    address payable _FEE_WALLET_ADDR_;
    address _DODO_APPROVE_ADDR_;
    address _WETH_;
    address _WETH_DFYN_;
    address _ETHER_WRAPPER_;
    /* ArkenDexV2 Proxy Storage: end */

    address public _CALLABLE_ADDRESS_;

    modifier onlyCallable() {
        require(
            _CALLABLE_ADDRESS_ == msg.sender,
            'ArkenApprove: caller is not callable address'
        );
        _;
    }

    event SetCallableAddress(
        address indexed oldAddress,
        address indexed newAddress
    );

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize(address _ownerAddress, address _callableAddress)
        public
        initializer
    {
        ownableUpgradeableInitialize();
        transferOwnership(_ownerAddress);
        _CALLABLE_ADDRESS_ = _callableAddress;
    }

    function initializeCallableAddress(address _callableAddress) external {
        require(
            _CALLABLE_ADDRESS_ == address(0),
            'ArkenApprove: callable address initialized'
        );
        _CALLABLE_ADDRESS_ = _callableAddress;
        emit SetCallableAddress(address(0), _callableAddress);
    }

    function updateCallableAddress(address _callableAddress)
        external
        onlyOwner
    {
        emit SetCallableAddress(address(0), _callableAddress);
        _CALLABLE_ADDRESS_ = _callableAddress;
    }

    function transferToken(
        IERC20 token,
        address from,
        address to,
        uint256 amount
    ) external onlyCallable {
        if (amount > 0) {
            token.safeTransferFrom(from, to, amount);
        }
    }
}
