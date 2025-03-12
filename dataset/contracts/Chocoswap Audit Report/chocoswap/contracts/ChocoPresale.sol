pragma solidity 0.6.12;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
contract ChocoPresale is Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    string private _name = "Proof of Choco Token";
    string private _symbol = "pChoc";
    uint8 private _decimals = 18;
    uint256 private _totalSupply;
    mapping (address => uint256) private _balances;

    uint256 public phaseIQ = 800e22;
    uint256 public phaseIIQ = 2675e22;
    uint256 public _totalSold;

    uint256 public phaseIR = 8000;
    uint256 public phaseIIR = 6250;


    uint256 public duration = 4 weeks;
    uint256 public preSaleStart = uint256(-1);
    uint256 public maxSupply = 1e26; // max pChoc supply 100 million

    address payable public ethReceiver = 0xDaBB2Fa102B48b4bC94746df6eF4e55324B7927f;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event OnEtherReceived(address indexed user, uint256 etherAmt, uint256 tokenAmt);
    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor () public {
        _mint(0xd31d7511fa27EB4DA838b9c5f28a1183a48A0F08, 7325e22);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    
    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public returns (bool) {
        require(msg.sender == owner(), "pChoc: not allowed to transfer");
        require(recipient != address(0), "pChoc: transfer to the zero address");

        _balances[msg.sender] = _balances[msg.sender].sub(amount, "pChoc: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(msg.sender, recipient, amount);
        return true;
    }

    function mint(address account, uint256 amount) public returns (bool) {
        require(msg.sender == owner(), "pChoc: not allowed to mint");
        require(preSalePhase() == 3, "pChoc: pre sale not ended");
        _mint(account, amount);
        return true;
    }
    
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "pChoc: mint to the zero address");
        _totalSupply = _totalSupply.add(amount);
        require(_totalSupply <= maxSupply, "pChoc: mint exceed max supply");
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    
    function setPreSaleStart(uint256 _startTime) public onlyOwner {
        preSaleStart = _startTime;
    }
    
    function withdraw() public {
        ethReceiver.transfer(address(this).balance);
    }
    
    receive () external payable nonReentrant {
        onEtherReceived();
    }

    // 0: not started, 1: phase I, 2: phase II, 3: ended
    function preSalePhase() public view returns (uint256) {
        uint256 now_ = block.timestamp;
        if (now_ < preSaleStart) {
            return 0;
        }
        if (now_ > preSaleStart.add(2 * duration) || _totalSold >= phaseIIQ) {
            return 3;
        }
        return _totalSold >= phaseIQ || now_ > preSaleStart.add(duration) ? 2 : 1;
    }
    function onEtherReceived() internal {
        uint256 receivedEther = msg.value;
        address buyer = msg.sender;
        uint256 phase = preSalePhase();
        require(phase == 1 || phase == 2, "preSale not started or ended");
        uint256 amount;
        if (phase == 1) {
            amount = phaseIR.mul(receivedEther);
            if (amount.add(_totalSold) > phaseIQ) {
                uint256 leftQ = phaseIQ.sub(_totalSold);
                // here we assume receivedEther is not enough to buy all the phase II choco tokens
                amount = receivedEther.sub(leftQ.div(phaseIR)).mul(phaseIIR).add(leftQ);
            }
        } else {
            amount = phaseIIR.mul(receivedEther);
            if (amount.add(_totalSold) > phaseIIQ) {
                amount = phaseIIQ.sub(_totalSold);
                msg.sender.transfer(receivedEther.sub(amount.div(phaseIIR)));
                receivedEther = amount.div(phaseIIR);
            }
        }
        // forward ether to etherReceiver
        ethReceiver.transfer(receivedEther);
        _mint(buyer, amount);
        _totalSold = _totalSold.add(amount);
        emit OnEtherReceived(buyer, receivedEther, amount);
    }
    
}