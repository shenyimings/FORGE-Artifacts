// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0.0;


// interface for callback on tokens sent
import "./Interfaces/IShareholder.sol";
import "./Interfaces/IWETH.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract RevenueSplitterWithController is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;

    IWETH public immutable WETH; 
    uint256 public totalShares;
    Shareholder[] internal _shareholders;

    struct Shareholder {
        address account;
        uint88 shares;
        bool toBeNotified;
    }

    constructor(IWETH wrappedEth) initializer {
        WETH = wrappedEth;
    }

    function initialize(
        Shareholder[] calldata initialShareholders
    ) public initializer {
        __Ownable_init();

        for(uint256 i = 0; i < initialShareholders.length; i++) {
            addShareholder(initialShareholders[i]);
        }
    }

    function distributeSingle(IERC20 token) public nonReentrant {
        if(address(token) == address(WETH)) wrap();

        (
            uint256 _balance,
            uint256 _totalShares,
            uint256 _shareholderCount
        ) = (
            token.balanceOf(address(this)), totalShares, _shareholders.length
        );

        require(_balance != 0, "nothing to distribute");

        unchecked {
            for(uint256 i = 0; i < _shareholderCount; i++) {
                Shareholder memory shareholder = _shareholders[i];
                uint256 transferAmount = _balance * shareholder.shares / _totalShares;

                IERC20(token).safeTransfer(shareholder.account, transferAmount);
                if(shareholder.toBeNotified) {
                    _notifyShareholder(shareholder.account, token, transferAmount);
                }
            } 
        }

        emit TokensDistributed(token, block.timestamp);
    }

    function wrap() public {
        WETH.deposit{ value: address(this).balance }();
    }

    function _notifyShareholder(
        address shareholder, 
        IERC20 token, 
        uint256 amount
    ) internal {
        require(
            IShareholder(shareholder)
                .notifyShareholder(address(token), amount), 
            "shareholder notification failed"
        );
    }


    //// owner functionality ////
    function addShareholder(Shareholder calldata shareholder) public onlyOwner {
        require(shareholder.account != address(0));
        totalShares += shareholder.shares;
        _shareholders.push(shareholder);
        emit ShareholderAdded(shareholder);
    }

    function updateShareholder(uint256 index, Shareholder calldata shareholder) public onlyOwner {
        Shareholder memory m_shareholder = _shareholders[index];
        require(shareholder.account == m_shareholder.account, "shareholder address immutable");
        totalShares = totalShares + shareholder.shares - m_shareholder.shares;
        _shareholders[index] = shareholder;
        emit ShareholderUpdated(shareholder.account, m_shareholder.shares, shareholder.shares);
    }

    function removeShareholders(uint256 index) public onlyOwner {
        Shareholder memory shareholder = _shareholders[index];
        totalShares -= shareholder.shares;
        uint256 lastIndex = _shareholders.length - 1;
        if(index != lastIndex) {
            Shareholder memory lastShareholder = _shareholders[lastIndex];
            _shareholders[index] = lastShareholder;            
        }
        _shareholders.pop();
        emit ShareholderRemoved(shareholder);
    }

    //// view ////

    function getShareholderCount() public view returns(uint256) {
        return _shareholders.length;
    }

    function getShareholder(uint256 index) public view returns(Shareholder memory) {
        return _shareholders[index];
    }

    fallback() external payable {wrap();}
    receive() external payable {wrap();}

    //// EVENTS ////

    event ShareholderAdded(Shareholder indexed newShareholder);
    event ShareholderRemoved(Shareholder indexed formerShareholder);
    event ShareholderUpdated(address indexed account, uint256 sharesBefore, uint256 sharesAfter);

    event TokensDistributed(IERC20 indexed token, uint256 indexed timestamp);
}