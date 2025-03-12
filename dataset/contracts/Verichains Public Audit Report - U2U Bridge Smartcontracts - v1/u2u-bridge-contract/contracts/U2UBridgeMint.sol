// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
// import "hardhat/console.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

interface U2V {
    function mint(address to, uint256 amount) external;
}

contract U2UBridgeMint is Ownable, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using Counters for Counters.Counter;

    /*
      event 
    */
    event MintToken(
        address indexed token,
        address indexed toAccount,
        uint256 indexed amount,
        bytes32 originHash,
        uint256 nonce,
        uint256 mintCount
    );
    event BurnToken(
        address indexed token,
        address indexed fromAccount,
        address indexed toAccount,
        uint256 amount,
        uint256 burnCounter
    );

    event TwoWayBridgeFlagChange(bool indexed flag);
    event AllowTokenEvent(address indexed token, bool indexed flag);
    event SetModOfTokenEvent(
        address indexed token,
        address indexed account,
        bool indexed flag
    );

    event OnlyEOACallEvent(address indexed token, bool indexed flag);
    event SetMinBurnEvent(address indexed token, uint256 indexed amount);

    event LackEventBridgeFlagChange(bool indexed flag);

    /*
        variable
    */

    mapping(address => bool) public isTokenAllowBridge;
    mapping(address => mapping(address => bool)) public isModOfToken;

    address public dead = 0x000000000000000000000000000000000000dEaD;
    bool public twoWayBridgeFlag = false;

    mapping(address => uint256) public totalMintOfToken;

    mapping(address => uint256) public minBurnToken;
    mapping(address => bool) public onlyEOACall;

    mapping(address => mapping(bytes32 => mapping(uint256 => bool)))
        public isHashUsed;
    Counters.Counter public mintCounter;
    Counters.Counter public burnCounter;

    bool public allowLackEvent = true;

    /*
      function 
    */

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

    function setMinBurnToken(address token, uint256 amount) public onlyOwner {
        require(token != address(0), "U2U-Bridge: token is the zero address");
        minBurnToken[token] = amount;
        emit SetMinBurnEvent(token, amount);
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

    function mintToken(
        address token,
        address toAccount,
        uint256 amount,
        bytes32 originHash,
        uint256 nonce
    ) external nonReentrant {
        require(isTokenAllowBridge[token], "U2U-BRidge: token not allow");
        require(
            isModOfToken[token][_msgSender()],
            "U2U-Bridge: user not allow call"
        );
        require(
            amount > minBurnToken[token],
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
        totalMintOfToken[token] += amount;
        U2V u2v = U2V(token);
        isHashUsed[token][originHash][nonce] = true;
        mintCounter.increment();
        if (!allowLackEvent) {
            require(
                mintCounter.current() == nonce,
                "U2U-BRidge: The system is maintenance"
            );
        }
        u2v.mint(toAccount, amount);
        
        emit MintToken(
            token,
            toAccount,
            amount,
            originHash,
            nonce,
            mintCounter.current()
        );
    }

    function burnToken(
        address token,
        address toAccount,
        uint256 amount
    ) external nonReentrant {
        require(twoWayBridgeFlag, "U2U-Bridge: action not allow");
        require(isTokenAllowBridge[token], "U2U-Bridge: token not allow");
        require(
            amount > minBurnToken[token],
            "U2U-BRidge amount less than minimum"
        );
        require(
            !onlyEOACall[token] ||
                (tx.origin == msg.sender &&
                    address(msg.sender).code.length == 0),
            "U2U-BRidge: only EOA call"
        );
        ERC20 tokenBridge = ERC20(token);
        totalMintOfToken[token] -= amount;
        tokenBridge.safeTransferFrom(_msgSender(), dead, amount);
        burnCounter.increment();
        emit BurnToken(
            token,
            _msgSender(),
            toAccount,
            amount,
            burnCounter.current()
        );
    }
}
