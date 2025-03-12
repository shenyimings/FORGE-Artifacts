// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract Mintable is Ownable {
    event SetMinterTimelock(address indexed setter, uint256 oldDuration, uint256 newDuration);
    event AllowMinter(address indexed setter, address indexed target, bool allowed);
    event SetDailyMintLimit(address indexed setter, uint256 oldLimit, uint256 newLimit);

    struct MinterData {
        bool allowed;
        uint256 timelock;
        uint256 dailyLimit;
    }

    uint256 public constant DAILY_INTERVAL = 1 days;

    uint256 public minterTimelock = 0; // in seconds, will be set later

    mapping(address => MinterData) public allowMinting;
    mapping(address => mapping(uint256 => uint256)) public dailyMint;

    function setMinterTimelock(uint256 _duration) public onlyOwner {
        require(_duration > minterTimelock, "Must be longer lock");
        emit SetMinterTimelock(_msgSender(), minterTimelock, _duration);
        minterTimelock = _duration;
    }

    function setAllowMinting(address _address, bool _allowed) public onlyOwner {
        if (_allowed) {
            allowMinting[_address].allowed = true;
            allowMinting[_address].timelock = block.timestamp + minterTimelock;
        } else {
            allowMinting[_address].allowed = false;
            allowMinting[_address].timelock = 0;
        }

        emit AllowMinter(_msgSender(), _address, _allowed);
    }

    function setDailyMintLimit(address _address, uint256 _limit) public onlyOwner {
        emit SetDailyMintLimit(_msgSender(), allowMinting[_address].dailyLimit, _limit);
        allowMinting[_address].dailyLimit = _limit;
    }

    modifier onlyMinter {
        require(allowMinting[_msgSender()].allowed, "not minter");
        require(block.timestamp >= allowMinting[_msgSender()].timelock, "mint locked");
        _;
    }

    function mintDailyLimited(address _address, uint256 _amount) public view returns (bool) {
        if (allowMinting[_address].dailyLimit == 0) {
            return false;
        }

        return dailyMint[_address][block.timestamp / DAILY_INTERVAL] + _amount > allowMinting[_address].dailyLimit;
    }

    function increaseMint(uint256 _amount) internal {
        require(!mintDailyLimited(_msgSender(), _amount), "mint limited");

        dailyMint[_msgSender()][block.timestamp / DAILY_INTERVAL] += _amount;
    }
}
