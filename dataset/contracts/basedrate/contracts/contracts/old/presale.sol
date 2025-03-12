//SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract BasedRateSale is Ownable, ReentrancyGuard {
    using Address for address payable;
    mapping(uint256 => address) public userIndex;
    mapping(address => UserData) public users;

    struct UserData {
        uint256 ethContributed;
        uint256 brateBought;
        uint256 bshareBought;
        bool whitelist;
        bool once;
        uint256 walletLimit;
    }

    uint256 public constant BRATEforSale = 27.5e18 * 1000;
    uint256 public constant BSHAREforSale = 27.5e18;
    uint256 public constant HARDCAP = 55e18;
    uint256 public walletLimitFCFS = 1e18;
    uint256 public walletMin = 1e16;
    uint256 public totalContribution;
    uint256 public userCount;
    uint256 public presaleStartTime = 1694106000;
    uint256 public FCFSstartTime = 14400 + presaleStartTime;
    uint256 public BRATEprice = (BRATEforSale * 1e18) / (HARDCAP);
    uint256 public BSHAREprice = (BSHAREforSale * 1e18) / (HARDCAP);
    bool public end;

    uint256 public totalBrateBought;
    uint256 public totalBshareBought;

    event buy(address buyer, uint256 value, uint256 brate, uint256 bshare);
    event End();
    event WhitelistedAddressAdded(address addr, uint256 limit);

    function setWalletParameters(uint256 _walletMin) public onlyOwner {
        walletMin = _walletMin;
    }

    function setEnd(bool _end) public onlyOwner {
        end = _end;
        emit End();
    }

    function addAddressToWhitelist(
        address addr,
        uint256 limit
    ) public onlyOwner returns (bool success) {
        UserData storage user = users[addr];
        user.whitelist = true;
        user.walletLimit = limit;
        emit WhitelistedAddressAdded(addr, limit);
        return true;
    }

    function _addAddressToWhitelist(
        address addr,
        uint256 limit
    ) private returns (bool added) {
        UserData storage user = users[addr];
        user.whitelist = true;
        user.walletLimit = limit;
        emit WhitelistedAddressAdded(addr, limit);
        return true;
    }

    function addAddressesToWhitelist(
        address[] memory addrs,
        uint256[] memory limits
    ) public onlyOwner returns (bool success) {
        require(addrs.length == limits.length, "Mismatched arrays");
        for (uint256 i = 0; i < addrs.length; i++) {
            if (_addAddressToWhitelist(addrs[i], limits[i])) {
                success = true;
            }
        }
    }

    function setTime(
        uint256 _FCFSstartTime,
        uint256 _presaleStartTime
    ) public onlyOwner {
        FCFSstartTime = _FCFSstartTime;
        presaleStartTime = _presaleStartTime;
    }

    function Buy() public payable nonReentrant {
        require(end == false, "presale is stopped");
        require(
            block.timestamp > FCFSstartTime || users[msg.sender].whitelist,
            "You are not Whitelist!"
        );
        require(users[msg.sender].once == false, "only one time");
        require(block.timestamp > presaleStartTime, "Not started yet!");
        uint256 amount = msg.value;
        if (!users[msg.sender].whitelist) {
            require(amount <= walletLimitFCFS, "max buy exceeded");
        } else {
            require(
                amount <= users[msg.sender].walletLimit,
                "max buy exceeded"
            );
        }
        require(amount >= walletMin, "min buy not reached");
        totalContribution += amount;
        require(totalContribution <= HARDCAP, "HARDCAP reached");
        if (!users[msg.sender].whitelist) {
            users[msg.sender].once = true;
        } else {
            users[msg.sender].whitelist = false;
        }
        if (users[msg.sender].ethContributed == 0) {
            userIndex[userCount] = msg.sender;
            userCount++;
        }
        users[msg.sender].ethContributed += amount;
        users[msg.sender].brateBought += (BRATEprice * amount) / 1e18;
        users[msg.sender].bshareBought += (BSHAREprice * amount) / 1e18;

        totalBrateBought += (BRATEprice * amount) / 1e18;
        totalBshareBought += (BSHAREprice * amount) / 1e18;

        emit buy(
            msg.sender,
            amount,
            (BRATEprice * amount) / 1e18,
            (BSHAREprice * amount) / 1e18
        );
    }

    function WithdrawETH(uint256 amount) public onlyOwner {
        payable(msg.sender).transfer(amount);
    }

    function WithdrawETHcall(uint256 amount) public onlyOwner {
        require(address(this).balance >= amount, "Not enough balance");
        payable(msg.sender).sendValue(amount);
    }

    function renounceOwnership() public virtual override onlyOwner {
        revert("Ownership renunciation is disabled");
    }

    function checkContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getUserData(address _user) public view returns (UserData memory) {
        return users[_user];
    }

    receive() external payable {}
}
