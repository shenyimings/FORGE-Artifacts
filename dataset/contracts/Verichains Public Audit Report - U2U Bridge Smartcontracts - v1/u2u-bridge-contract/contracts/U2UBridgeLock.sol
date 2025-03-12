// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract U2UBridgeLock is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using Counters for Counters.Counter;

    /*
    event
    */

    event Lock(
        address indexed token,
        address indexed fromAccount,
        address indexed toAccount,
        uint256 amount,
        uint256 lockCounter
    );
    event UnLock(
        address indexed token,
        address indexed toAccount,
        uint256 indexed amount,
        bytes32 originHash,
        uint256 nonce,
        uint256 unlockCounter
    );

    event TwoWayBridgeFlagChange(bool indexed flag);
    event AllowTokenEvent(address indexed token, bool indexed flag);
    event SetModOfTokenEvent(
        address indexed token,
        address indexed account,
        bool indexed flag
    );
    event OnlyEOACallEvent(address indexed token, bool indexed flag);
    event SetMinLockEvent(address indexed token, uint256 indexed amount);
    event LackEventBridgeFlagChange(bool indexed flag);

    /*
    variable

    */

    mapping(address => bool) public isTokenAllowBridge;
    mapping(address => mapping(address => bool)) public isModOfToken;
    mapping(address => uint256) public totalLockOfToken;

    mapping(address => uint256) public minLockToken;
    mapping(address => bool) public onlyEOACall;

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public isHashUsed;

    Counters.Counter public lockCounter;

    Counters.Counter public unLockCounter;

    bool public twoWayBridgeFlag = false;
    bool public allowLackEvent = true;



    function set2WayBridgeFlag(bool flag) public onlyOwner {
        twoWayBridgeFlag = flag;
        emit TwoWayBridgeFlagChange(flag);
    }

    function setTokenAllow(address token, bool flag) public onlyOwner {
        require(token != address(0), "U2U-Bridge: token is the zero address");
        isTokenAllowBridge[token] = flag;
        emit AllowTokenEvent(token, flag);
    }

    function setTokenMod(
        address token,
        address account,
        bool flag
    ) public onlyOwner {
        require(token != address(0), "U2U-Bridge: token is the zero address");
        require(account != address(0), "U2U-Bridge: account is the zero address");
        isModOfToken[token][account] = flag;
        emit SetModOfTokenEvent(token, account, flag);
    }

    function setMinLockToken(address token, uint256 amount) public onlyOwner {
        require(token != address(0), "U2U-Bridge: token is the zero address");
        minLockToken[token] = amount;
        emit SetMinLockEvent(token, amount);
    }

    function setOnlyEOACall(address token, bool flag) public onlyOwner {
        require(token != address(0), "U2U-Bridge: token is the zero address");
        onlyEOACall[token] = flag;
        emit OnlyEOACallEvent(token, flag);
    }

    function setAllowLackEvent(bool flag) public onlyOwner {
        allowLackEvent = flag;
        emit LackEventBridgeFlagChange(flag);
    }

    function lockToken(
        address token,
        address toAccount,
        uint256 amount
    ) external nonReentrant {
        require(isTokenAllowBridge[token], "U2U-BRidge: token not allow");
        require(
            amount > minLockToken[token],
            "U2U-BRidge amount less than minimum"
        );
        require(
            !onlyEOACall[token] ||
                (tx.origin == msg.sender &&
                    address(msg.sender).code.length == 0),
            "U2U-BRidge: only EOA call"
        );
        ERC20 tokenBridge = ERC20(token);
        totalLockOfToken[token] += amount;
        tokenBridge.safeTransferFrom(_msgSender(), address(this), amount);
        lockCounter.increment();
        emit Lock(
            token,
            _msgSender(),
            toAccount,
            amount,
            lockCounter.current()
        );
    }

    function unLockToken(
        address token,
        address toAccount,
        uint256 amount,
        bytes32 originHash,
        uint256 nonce
    ) external nonReentrant {
        require(twoWayBridgeFlag, "U2U-Bridge: action not allow");
        require(isTokenAllowBridge[token], "U2U-Bridge: token not allow");
        require(
            isModOfToken[token][_msgSender()],
            "U2U-Bridge: user not allow call"
        );
        require(
            amount > minLockToken[token],
            "U2U-BRidge amount less than minimum"
        );
        require(
            !onlyEOACall[token] ||
                (tx.origin == msg.sender &&
                    address(msg.sender).code.length == 0),
            "U2U-BRidge: only EOA call"
        );
        require(
            !isHashUsed[token][originHash][nonce],
            "U2U-Bridge: hash already used"
        );

        ERC20 tokenBridge = ERC20(token);
        totalLockOfToken[token] -= amount;
        isHashUsed[token][originHash][nonce] = true;
        unLockCounter.increment();
        if (!allowLackEvent) {
            require(
                unLockCounter.current() == nonce,
                "U2U-BRidge: The system is maintenance"
            );
        }
        tokenBridge.safeTransfer(toAccount, amount);
       
        emit UnLock(
            token,
            toAccount,
            amount,
            originHash,
            nonce,
            unLockCounter.current()
        );
    }
}
