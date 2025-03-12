import "@openzeppelin/interfaces/IERC20.sol";

contract Pool {
    IERC20 public tokenContract0;
    IERC20 public tokenContract1;

    constructor(address _token0, address _token1) {
        tokenContract0 = IERC20(_token0);
        tokenContract1 = IERC20(_token1);
    }

    function balanceOf(address _account) external view returns (uint256, uint256) {
        return (tokenContract0.balanceOf(_account), tokenContract1.balanceOf(_account));
    }

    function poolBalances() external view returns (uint256, uint256) {
        return (tokenContract0.balanceOf(address(this)), tokenContract1.balanceOf(address(this)));
    }

    function name() external view returns (string memory, string memory) {
        return (tokenContract0.name(), tokenContract1.name());
    }

    function symbol() external view returns (string memory, string memory) {
        return (tokenContract0.symbol(), tokenContract1.symbol());
    }

    function decimals() external view returns (uint8, uint8) {
        return (tokenContract0.decimals(), tokenContract1.decimals());
    }

    // Deposit some tokens into the pool
    function deposit(uint256 _amount0, uint256 _amount1) external returns (bool, bool) {
        return (tokenContract0.transferFrom(msg.sender, address(this), _amount0), tokenContract1.transferFrom(msg.sender, address(this), _amount1));
    }

    // Withdraw some tokens from the pool.
    // Note that any user can withdraw any amount of tokens from the pool.
    function withdraw(uint256 _amount0, uint256 _amount1) external returns (bool, bool) {
        return (tokenContract0.transfer(msg.sender, _amount0), tokenContract1.transfer(msg.sender, _amount1));
    }
}