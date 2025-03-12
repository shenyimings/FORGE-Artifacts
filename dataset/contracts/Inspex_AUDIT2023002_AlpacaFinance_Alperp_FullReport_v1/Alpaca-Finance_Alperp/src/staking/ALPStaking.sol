// SPDX-License-Identifier: MIT
/**
  ∩~~~~∩ 
  ξ ･×･ ξ 
  ξ　~　ξ 
  ξ　　 ξ 
  ξ　　 “~～~～〇 
  ξ　　　　　　 ξ 
  ξ ξ ξ~～~ξ ξ ξ 
　 ξ_ξξ_ξ　ξ_ξξ_ξ
Alpaca Fin Corporation
*/
pragma solidity 0.8.17;

import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import {IRewarder} from "./interfaces/IRewarder.sol";
import {IStaking} from "./interfaces/IStaking.sol";

contract ALPStaking is IStaking, OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    error ALPStaking_UnknownStakingToken();
    error ALPStaking_InsufficientTokenAmount();
    error ALPStaking_NotRewarder();
    error ALPStaking_NotCompounder();
    error ALPStaking_BadDecimals();
    error ALPStaking_DuplicateStakingToken();

    mapping(address => mapping(address => uint256)) public userTokenAmount;
    mapping(address => bool) public isRewarder;
    mapping(address => bool) public isStakingToken;
    mapping(address => address[]) public stakingTokenRewarders;
    mapping(address => address[]) public rewarderStakingTokens;

    address public compounder;

    event LogDeposit(
        address indexed caller,
        address indexed user,
        address token,
        uint256 amount
    );
    event LogWithdraw(address indexed caller, address token, uint256 amount);
    event LogAddStakingToken(address newToken, address[] newRewarders);
    event LogAddRewarder(address newRewarder, address[] newTokens);
    event LogSetCompounder(address oldCompounder, address newCompounder);

    function initialize() external initializer {
        OwnableUpgradeable.__Ownable_init();
    }

    function addStakingToken(address newToken, address[] memory newRewarders)
        external
        onlyOwner
    {
        if (ERC20Upgradeable(newToken).decimals() != 18)
            revert ALPStaking_BadDecimals();

        uint256 length = newRewarders.length;
        for (uint256 i = 0; i < length; ) {
            _updatePool(newToken, newRewarders[i]);

            emit LogAddStakingToken(newToken, newRewarders);
            unchecked {
                ++i;
            }
        }
    }

    function addRewarder(address newRewarder, address[] memory newTokens)
        external
        onlyOwner
    {
        uint256 length = newTokens.length;
        for (uint256 i = 0; i < length; ) {
            if (ERC20Upgradeable(newTokens[i]).decimals() != 18)
                revert ALPStaking_BadDecimals();

            _updatePool(newTokens[i], newRewarder);

            emit LogAddRewarder(newRewarder, newTokens);
            unchecked {
                ++i;
            }
        }
    }

    function removeRewarderForTokenByIndex(
        uint256 removeRewarderIndex,
        address token
    ) external onlyOwner {
        uint256 tokenLength = stakingTokenRewarders[token].length;
        address removedRewarder = stakingTokenRewarders[token][
            removeRewarderIndex
        ];
        stakingTokenRewarders[token][
            removeRewarderIndex
        ] = stakingTokenRewarders[token][tokenLength - 1];
        stakingTokenRewarders[token].pop();

        uint256 rewarderLength = rewarderStakingTokens[removedRewarder].length;
        for (uint256 i = 0; i < rewarderLength; ) {
            if (rewarderStakingTokens[removedRewarder][i] == token) {
                rewarderStakingTokens[removedRewarder][
                    i
                ] = rewarderStakingTokens[removedRewarder][rewarderLength - 1];
                rewarderStakingTokens[removedRewarder].pop();
                if (rewarderLength == 1) isRewarder[removedRewarder] = false;

                break;
            }
            unchecked {
                ++i;
            }
        }
    }

    function _updatePool(address newToken, address newRewarder) internal {
        if (!isDuplicatedRewarder(newToken, newRewarder))
            stakingTokenRewarders[newToken].push(newRewarder);
        if (!isDuplicatedStakingToken(newToken, newRewarder))
            rewarderStakingTokens[newRewarder].push(newToken);

        isStakingToken[newToken] = true;
        if (!isRewarder[newRewarder]) {
            isRewarder[newRewarder] = true;
        }
    }

    function isDuplicatedRewarder(address stakingToken, address rewarder)
        internal
        view
        returns (bool)
    {
        uint256 length = stakingTokenRewarders[stakingToken].length;
        for (uint256 i = 0; i < length; ) {
            if (stakingTokenRewarders[stakingToken][i] == rewarder) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function isDuplicatedStakingToken(address stakingToken, address rewarder)
        internal
        view
        returns (bool)
    {
        uint256 length = rewarderStakingTokens[rewarder].length;
        for (uint256 i = 0; i < length; ) {
            if (rewarderStakingTokens[rewarder][i] == stakingToken) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function setCompounder(address compounder_) external onlyOwner {
        emit LogSetCompounder(compounder, compounder_);
        compounder = compounder_;
    }

    function deposit(
        address to,
        address token,
        uint256 amount
    ) external {
        if (!isStakingToken[token]) revert ALPStaking_UnknownStakingToken();

        uint256 length = stakingTokenRewarders[token].length;
        for (uint256 i = 0; i < length; ) {
            address rewarder = stakingTokenRewarders[token][i];

            IRewarder(rewarder).onDeposit(to, amount);

            unchecked {
                ++i;
            }
        }

        userTokenAmount[token][to] += amount;
        IERC20Upgradeable(token).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );

        emit LogDeposit(msg.sender, to, token, amount);
    }

    function getUserTokenAmount(address token, address sender)
        external
        view
        returns (uint256)
    {
        return userTokenAmount[token][sender];
    }

    function getStakingTokenRewarders(address token)
        external
        view
        returns (address[] memory)
    {
        return stakingTokenRewarders[token];
    }

    function withdraw(address token, uint256 amount) external {
        _withdraw(token, amount);
        emit LogWithdraw(msg.sender, token, amount);
    }

    function _withdraw(address token, uint256 amount) internal {
        if (!isStakingToken[token]) revert ALPStaking_UnknownStakingToken();
        if (userTokenAmount[token][msg.sender] < amount)
            revert ALPStaking_InsufficientTokenAmount();

        uint256 length = stakingTokenRewarders[token].length;
        for (uint256 i = 0; i < length; ) {
            address rewarder = stakingTokenRewarders[token][i];

            IRewarder(rewarder).onWithdraw(msg.sender, amount);

            unchecked {
                ++i;
            }
        }
        userTokenAmount[token][msg.sender] -= amount;
        IERC20Upgradeable(token).safeTransfer(msg.sender, amount);
        emit LogWithdraw(msg.sender, token, amount);
    }

    function harvest(address[] memory rewarders) external {
        _harvestFor(msg.sender, msg.sender, rewarders);
    }

    function harvestToCompounder(address user, address[] memory rewarders)
        external
    {
        if (compounder != msg.sender) revert ALPStaking_NotCompounder();
        _harvestFor(user, compounder, rewarders);
    }

    function _harvestFor(
        address user,
        address receiver,
        address[] memory rewarders
    ) internal {
        uint256 length = rewarders.length;
        for (uint256 i = 0; i < length; ) {
            if (!isRewarder[rewarders[i]]) {
                revert ALPStaking_NotRewarder();
            }

            IRewarder(rewarders[i]).onHarvest(user, receiver);

            unchecked {
                ++i;
            }
        }
    }

    function calculateShare(address rewarder, address user)
        external
        view
        returns (uint256)
    {
        address[] memory tokens = rewarderStakingTokens[rewarder];
        uint256 share = 0;
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ) {
            share += userTokenAmount[tokens[i]][user];

            unchecked {
                ++i;
            }
        }
        return share;
    }

    function calculateTotalShare(address rewarder)
        external
        view
        returns (uint256)
    {
        address[] memory tokens = rewarderStakingTokens[rewarder];
        uint256 totalShare = 0;
        uint256 length = tokens.length;
        for (uint256 i = 0; i < length; ) {
            totalShare += IERC20Upgradeable(tokens[i]).balanceOf(address(this));

            unchecked {
                ++i;
            }
        }
        return totalShare;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
}
