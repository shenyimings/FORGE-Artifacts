import "./MockERC20.sol";

contract Mock3CRV is MockERC20 {
    constructor() ERC20("3crv", "3crv", 18) {}

    function faucet(uint256 amount) external override {
        _mint(msg.sender, 10000e18);
    }
}
