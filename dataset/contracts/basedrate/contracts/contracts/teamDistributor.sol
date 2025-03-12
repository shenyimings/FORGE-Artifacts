//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

interface ISHARE {
    function setDevFund(address _devFund) external;

    function claimRewards() external;
}

contract TeamDistributor is Ownable {
    using Address for address payable;
    uint256 private arrayLimit = 200;
    uint256 public brateAmount;
    uint256 public bshareAmount;
    address public BRATE;
    address public BSHARE;
    address[] public team;
    address public caller;
    ISHARE public SHARE;

    event ExecuteTransaction(
        bytes32 indexed txHash,
        address indexed target,
        uint value,
        string signature,
        bytes data
    );
    event Multisended(uint256 total, address tokenAddress);

    function setAmounts(uint256 _brate, uint256 _bshare) public onlyOwner {
        brateAmount = _brate;
        bshareAmount = _bshare;
    }

    function setCaller(address _caller) public onlyOwner {
        caller = _caller;
    }

    modifier onlyCaller() {
        require(caller == msg.sender);
        _;
    }

    function setDevFund(address _devfund) public onlyOwner {
        SHARE.setDevFund(_devfund);
    }

    function getArrayLimit() public view returns (uint256) {
        return arrayLimit;
    }

    function setArrayLimit(uint256 _newLimit) public onlyOwner {
        require(_newLimit != 0);
        arrayLimit = _newLimit;
    }

    function setTeam(address[] memory _team) public onlyOwner {
        team = _team;
    }

    function setTokens(address _BSHARE, address _BRATE) public onlyOwner {
        BSHARE = _BSHARE;
        SHARE = ISHARE(_BSHARE);
        BRATE = _BRATE;
    }

    function distribute(
        address token,
        address[] memory _receivers,
        uint256 amount
    ) external onlyOwner {
        uint256 total = 0;
        require(
            _receivers.length <= getArrayLimit(),
            "Array length exceeds limit"
        );
        uint256 toSend = amount / _receivers.length;
        IERC20 erc20token = IERC20(token);
        for (uint8 i = 0; i < _receivers.length; i++) {
            erc20token.transfer(_receivers[i], toSend);
            total += toSend;
        }

        emit Multisended(total, token);
    }

    function automatedDistribution() external onlyCaller {
        uint256 totalBrate = 0;
        uint256 totalBshare = 0;
        require(team.length <= getArrayLimit(), "Array length exceeds limit");
        IERC20 brate = IERC20(BRATE);
        IERC20 bshare = IERC20(BSHARE);
        uint256 amountBrate = brate.balanceOf(address(this));
        uint256 toSendBrate = 0;
        uint256 amountBshare = bshare.balanceOf(address(this));
        uint256 toSendBshare = 0;
        if (amountBrate > 0) {
            toSendBrate = amountBrate / team.length;
        }
        if (amountBshare > 0) {
            toSendBshare = amountBshare / team.length;
        }
        for (uint8 i = 0; i < team.length; i++) {
            brate.transfer(team[i], toSendBrate);
            bshare.transfer(team[i], toSendBshare);
            totalBrate += toSendBrate;
            totalBshare += toSendBshare;
        }
        emit Multisended(totalBrate, BRATE);
        emit Multisended(totalBshare, BSHARE);
    }

    function automatedDistributionFixedRate() external onlyCaller {
        uint256 totalBrate = 0;
        uint256 totalBshare = 0;
        SHARE.claimRewards();
        require(team.length <= getArrayLimit(), "Array length exceeds limit");
        IERC20 brate = IERC20(BRATE);
        IERC20 bshare = IERC20(BSHARE);
        uint256 amountBrate = brateAmount;
        uint256 toSendBrate = 0;
        uint256 amountBshare = bshareAmount;
        uint256 toSendBshare = 0;

        if (amountBrate > 0) {
            toSendBrate = amountBrate / team.length;
        }

        if (amountBshare > 0) {
            toSendBshare = amountBshare / team.length;
        }

        for (uint8 i = 0; i < team.length; i++) {
            brate.transfer(team[i], toSendBrate);
            bshare.transfer(team[i], toSendBshare);
            totalBrate += toSendBrate;
            totalBshare += toSendBshare;
        }

        emit Multisended(totalBrate, BRATE);
        emit Multisended(totalBshare, BSHARE);
    }

    function singleSendTokens(
        address tokenAddress,
        address to,
        uint256 amount
    ) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(to, amount);
    }

    function rescueETH(address to, uint256 amount) external onlyOwner {
        payable(to).sendValue(amount);
    }

    function renounceOwnership() public virtual override onlyOwner {
        revert("Ownership renunciation is disabled");
    }


    // to interact with other contracts
    function sendCustomTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data
    ) public payable onlyOwner returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data));
        bytes memory callData;
        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(
                bytes4(keccak256(bytes(signature))),
                data
            );
        }
        (bool success, bytes memory returnData) = target.call{value: value}(
            callData
        );
        require(success, "Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data);

        return returnData;
    }

    receive() external payable {}
}
