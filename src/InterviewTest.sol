//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./interfaces/ISwapRouter.sol";
import "./Math.sol";

interface ILendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;

    function withdraw(
        address asset,
        uint256 amount,
        address to
    ) external returns (uint256);
}

interface IWETHGateway {
    function depositETH(
        address lendingPool,
        address onBehalfOf,
        uint16 referralCode
    ) external payable;

    function withdrawETH(
        address lendingPool,
        uint256 amount,
        address onBehalfOf
    ) external;
}

interface IUniswapRouter is ISwapRouter {
    function refundETH() external payable;
}

contract InterviewTest is ERC20Burnable, Ownable, Math {
    using SafeMath for uint256;

    uint256 public totalBorrowed;
    uint256 public totalDeposit;
    uint256 public totalCollateral;
    uint256 public baseRate = 2 * 10**16;

    IERC20 public constant dai =
        IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    AggregatorV3Interface internal constant priceFeed =
        AggregatorV3Interface(0x773616e4d11a78f511299002da57a0a94577f1f4);

    mapping(address => uint256) private usersCollateral;
    mapping(address => uint256) private usersBorrowed;

    constructor() ERC20("Bond DAI", "bDAI") {}

    function bondAsset(uint256 _amount) public {
        totalDeposit += _amount;
        _mint(msg.sender, _amount);
        dai.transferFrom(msg.sender, address(this), _amount);
    }

    function unbondAsset(uint256 _amount) public {
        require(balanceOf(msg.sender) - _amount >= 0, "Not enough bonds!");
        totalDeposit -= _amount;
        burn(_amount);
        dai.transfer(msg.sender, _amount);
    }

    function addCollateral() public payable {
        require(msg.value > 0, "Cant send 0 ethers");
        usersCollateral[msg.sender] += msg.value;
        totalCollateral += msg.value;
    }

    function removeCollateral(uint256 _amount) public payable {
        require(usersCollateral[msg.sender] > 0, "Dont have any collateral");
        msg.sender.call{value: _amount}("");

        usersCollateral[msg.sender] -= _amount;
        totalCollateral -= _amount;
    }

    function borrow(uint256 _amount) public {
        require(
            _ETHtoDai(usersCollateral[msg.sender]) - _amount > 0,
            "No collateral enough"
        );
        usersBorrowed[msg.sender] += _amount;
        totalBorrowed += _amount;
        dai.transfer(msg.sender, _amount);
    }

    function repay(uint256 _amount) public {
        require(usersBorrowed[msg.sender] > 0, "Dont have any debt to pay");
        uint256 paidAmount = (_amount * (10**18 - baseRate)) / 10**18;
        usersBorrowed[msg.sender] -= paidAmount;
        totalBorrowed -= paidAmount;
        dai.transferFrom(msg.sender, address(this), _amount);
    }

    function _ETHtoDai(uint256 amount) public returns (uint256) {
        uint256 price = uint256(_getLatestPrice());
        return amount / price;
    }

    function _DaiToETH(uint256 amount) public returns (uint256) {
        uint256 price = uint256(_getLatestPrice());
        return amount * price;
    }

    function _getLatestPrice() public view returns (int256) {
        (, int256 price, , , ) = priceFeed.latestRoundData();
        return price;
    }

    function getCollateral() external view returns (uint256) {
        return usersCollateral[msg.sender];
    }

    function getBorrowed() external view returns (uint256) {
        return usersBorrowed[msg.sender];
    }

    receive() external payable {}

    fallback() external payable {}
}
