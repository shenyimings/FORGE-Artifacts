// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IVotingEscrow.sol";


contract ProtocolAirdrop {

    using SafeERC20 for IERC20;

    address public owner;
    IVotingEscrow public ve;
    IERC20 public token;
    
    uint public constant LOCK = 86400 * 7 * 52 * 2;

    mapping (address => bool) depositors;

    modifier onlyOwner {
        require(msg.sender == owner, 'not owner');
        _;
    }

    event Deposit(uint256 amount);
    event Withdraw(uint256 amount);

    constructor(address _token, address _ve) {
        owner = msg.sender;
        token = IERC20(_token);
        ve = IVotingEscrow(_ve);
    }

    /* 
        OWNER FUNCTIONS
    */

    function setDepositor(address depositor, bool _status) external onlyOwner {
        require(depositors[depositor] == !_status);
        depositors[depositor] = _status;
    }

    function setOwner(address _owner) external onlyOwner{
        require(_owner != address(0));
        owner = _owner;
    }

    /// @notice set the veCHR address
    function setVe(address _ve) external onlyOwner{
        require(_ve != address(0));
        ve = IVotingEscrow(_ve);
    }


    function deposit(uint256 amount) external {
        require(depositors[msg.sender] == true || msg.sender == owner);
        token.safeTransferFrom(msg.sender, address(this), amount);
        token.approve(address(ve), token.balanceOf(address(this)));
        
        emit Deposit(amount);
    }
    
    function withdraw(uint256 amount) external {
        require(msg.sender == owner);
        uint available = token.balanceOf(address(this));
        require(available >= amount, "Not enough balance in this wallet");
        token.safeTransfer(msg.sender, amount);
        token.approve(address(ve), token.balanceOf(address(this)));

        
        emit Withdraw(amount);
    }

    function giveToProtocol(address[] memory _to, uint256[] memory _amount) public {
        require(depositors[msg.sender] == true || msg.sender == owner);
        require(_to.length == _amount.length);

        uint _tokenId;
        for (uint i = 0; i < _to.length; i++) {
            _tokenId = ve.create_lock_for(_amount[i], LOCK, _to[i]);
        
            ve.setProtocolAirdrop(_tokenId, true);
        }

    }



    
}