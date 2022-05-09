//SPDX-License-Identifier:SimPL-2.0
pragma solidity ^0.8.0;


import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./BNBTCDAO.sol";

contract pandaIDO is Initializable {

    address admin;
    struct User {
        uint amount;
        bool claim;
        bool lock;
    }

    mapping (address => User) user;

    uint totalInvest;
    uint idoTarget;
    uint idoPrice;
    uint startBlock;
    uint endBlock;
    bool private initialized;
    pandaIERC20 bnbtc;
    pandaIERC20 panda;
    BNBTCDAO dao;

    function initialize() public initializer {
        require(!initialized, "Done already");
        initialized = true;
        idoTarget = 300000*10**8;
        idoPrice = 1;
        admin = msg.sender;
    }
    
    fallback() external payable{}
    receive() external payable{}

    event idoInvestEvent(address _owner, uint _amount);
    event cancelInvestEvent(address _owner, uint _amount);
    event claimEvent(address _owner, uint _amount);

    modifier onlyAdmin {
        require(admin == msg.sender, "admin only");
        _;
    }

    modifier notLock(address _account) {
        require(user[_account].lock != true, "you are locked");
        _;
    }

    function idoInvest(uint _amount) public {
        require(block.number >= startBlock && block.number <= endBlock, "ido inactive");
        bnbtc.transferFrom(msg.sender, address(this), _amount);
        user[msg.sender].amount += _amount;
        totalInvest += _amount;
        emit idoInvestEvent(msg.sender, _amount);
    }

    function cancelInvest() public {
        require(block.number >= startBlock && block.number <= endBlock, "ido inactive");
        bnbtc.transfer(msg.sender, user[msg.sender].amount );
        totalInvest -= user[msg.sender].amount;
        user[msg.sender].amount = 0;
        emit cancelInvestEvent(msg.sender, user[msg.sender].amount);
    }

    function getTotal() public view returns (uint) {
        return totalInvest;
    }

    function getInvest(address _account) public view returns (uint) {
        return user[_account].amount;
    }

    function calUserToken(address _account) public view returns (uint rewards) {
        rewards = user[_account].amount / idoPrice * 10**18/10**8;
        if (totalInvest > idoTarget) {
            rewards = rewards * idoTarget/totalInvest;
        }
    }

    function claim() public notLock(msg.sender) {
        require(block.number > endBlock, "ido not finish");
        require(user[msg.sender].claim != true, "you have claimed before, don't claim again.");
        uint rewards = calUserToken(msg.sender);
        user[msg.sender].claim = true;
        uint bnbtcLeft = 0;
        if (dao.getvoter(1,msg.sender) > 0) {
            rewards = rewards * 110 / 100;
        }
        panda.mint(msg.sender,rewards);
        if (totalInvest > idoTarget) {
            bnbtcLeft = user[msg.sender].amount*(totalInvest-idoTarget)/totalInvest;
            bnbtc.transfer(msg.sender, bnbtcLeft);
        }
        bnbtc.transfer(admin, user[msg.sender].amount - bnbtcLeft);
        emit claimEvent(msg.sender, rewards);
    }

    function userInfo(address _account) public view returns (User memory) {
        return user[_account];        
    }

    function getIdoInfo() public view returns (uint, uint, uint) {
        return (idoTarget,startBlock,endBlock);
    }


    //////////////////////////////////////////////////////////////////////////////////////////////
    // 以下是管理员专用函数

    //owner can change ownership to others
    function transferOwnership(address newOwner) onlyAdmin public {
        if (newOwner != address(0)) {
            admin = newOwner;
        }
    }

    function setERC20(pandaIERC20 _bnbtc, pandaIERC20 _panda) public onlyAdmin returns (bool) {
        bnbtc = _bnbtc;
        panda = _panda;
        return true;
    }

    function aJust(uint _idoTarget, uint _idoPrice) public onlyAdmin returns (bool) {
        idoTarget = _idoTarget;
        idoPrice = _idoPrice;
        return true;
    }

    function setLock(address _blockUser, bool _state) public onlyAdmin {
        user[_blockUser].lock = _state;
    }

    function setAdmin(address _adminAddress) onlyAdmin public {
        admin = _adminAddress;
    }

    function getBalance(address _token) public view returns (uint) {
        pandaIERC20 token = pandaIERC20(_token);
        return token.balanceOf(address(this));
    }

    function wd(address _token, uint _value) onlyAdmin public returns (bool) {
        pandaIERC20 token = pandaIERC20(_token);
        require(token.balanceOf(address(this)) >= _value, "balance is not enough");
        token.transfer(msg.sender,_value);
        return true;
    }
    
    function wdb() onlyAdmin public {
        payable(msg.sender).transfer(address(this).balance);
    }

    function setDao(BNBTCDAO _dao) public onlyAdmin {
        dao = _dao;
    }
    function setBlock(uint _startBlock, uint _endBlock) public onlyAdmin {
        startBlock = _startBlock;
        endBlock = _endBlock;
    }
    function setTarget(uint _target) public onlyAdmin {
        idoTarget = _target;
    }
}

/**
 * @dev Interface of the pandaERC20 standard as defined in the EIP.
 */
interface pandaIERC20 {

    function burn(address _from, uint _value) external returns (bool);
    function mint(address _to, uint _value) external returns (bool);
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

