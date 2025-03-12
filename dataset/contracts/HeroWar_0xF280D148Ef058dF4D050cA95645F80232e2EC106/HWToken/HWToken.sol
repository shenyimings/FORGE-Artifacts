pragma solidity >=0.5.0;
// SPDX-License-Identifier: Unlicensed

library SafeMath {
    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }


    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

   
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

   
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {

        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

   
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

   
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

   
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }


    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}
interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
}
interface IPool{
    function injectPool(uint256 amount )external;
}
 
contract HWToken is IERC20 {

    using SafeMath for uint256;

    mapping (address => uint256) internal _tOwned;
    mapping (address => mapping (address => uint256)) internal _allowances;

    string internal _name; 
    string internal _symbol;
    uint256 internal _decimals;
    uint256 internal _tTotal;
    
    address public _owner;
    IPool public pool;

    uint public daoRate;
    uint public bnbRate;
    address public uniswapV2Pair;
    address public dao;

    mapping( address => bool) public inWhiteList;

    modifier onlyOwner() {
        require(msg.sender == _owner, "admin: wut?");
        _;
    }
    
    constructor (
        uint256 _supply,
        address _dao,
        address _holder,
        address _ownerAddress
    ) public {
        daoRate = 3;
        bnbRate = 9;
        dao = _dao;
        _decimals = 18;
        _tTotal = _supply * 10 ** _decimals;
        _name = "Hero War";
        _symbol = "HW";

        inWhiteList[_holder] = true;

        _tOwned[_holder] = _tTotal;
       emit Transfer(address(0), _holder, _tTotal);
        
        _owner = _ownerAddress;
    }

    function setPool(address _pool)external onlyOwner{
        pool = IPool(_pool);
    }

    function setPair(address _pair)external onlyOwner{
        uniswapV2Pair = _pair;
    }

    function setDao(address _dao)external onlyOwner{
        dao = _dao;
    }

    function setDaoRate(uint r)external onlyOwner{
        daoRate = r;
    }

    function setBnbRate(uint r) external onlyOwner{
        bnbRate = r;
    }

    function setWhiteList(address owner,bool isIn)external onlyOwner{
        inWhiteList[owner] = isIn;
    }

    function transferOwner(address newO)external  onlyOwner{
        _owner = newO;
    }
  
    function name() public override view returns (string memory) {
        return _name;
    }

    function symbol() public override view returns (string memory) {
        return _symbol;
    }

    function decimals() public override view returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
         return _tOwned[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);

        address msgSender = msg.sender;
        _approve(sender, msgSender, _allowances[sender][msgSender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public  returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public  returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }


    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");

        require(amount > 0, "Transfer amount must be greater than zero");

        uint acceptAmount = amount;

        if( ( to == uniswapV2Pair || from == uniswapV2Pair)  && !inWhiteList[from]){

            uint fee1 = amount * daoRate / 100;
            uint fee2 = amount * bnbRate / 100;

            acceptAmount -= fee1;
            acceptAmount -= fee2;

            _tOwned[address(pool)] = _tOwned[address(pool)].add(fee2);

            if( address(pool) != address(0)){
                pool.injectPool(fee2);
            }
            
            emit Transfer(from, address(pool), fee2);

            _tOwned[dao] = _tOwned[dao].add(fee1);
            emit Transfer(from, dao, fee1);
        }
       

        _tOwned[from] = _tOwned[from].sub(amount);
        _tOwned[to] = _tOwned[to].add(acceptAmount);
        emit Transfer(from, to, acceptAmount);
    }
}