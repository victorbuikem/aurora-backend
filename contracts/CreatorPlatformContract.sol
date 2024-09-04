// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CreatorPlatformContract
 * @dev Manages user interactions, donations, creator registrations,
 *      content uploads, and withdrawals using ETH.
 */
contract CreatorPlatformContract is Ownable {
    struct Creator {
        string name;
        bool isRegistered;
    }

    struct Content {
        address creator;
        string ipfsHash;
        string title;
        string fileType;
        uint256 currentDonation;
        uint256 donatorsCount;
        string contentCategory;
    }

    mapping(address => Creator) public creators;
    mapping(string => Content[]) private contentByCategory;
    mapping(address => Content[]) private contentByCreator;
    mapping(address => mapping(string => uint256)) private contentIndexByHash; 
    mapping(address => mapping(uint256 => bool)) private donors;

    event CreatorRegistered(address indexed creatorAddress, string name);
    event ContentUploaded(address indexed creatorAddress, string ipfsHash, string title, string contentCategory);
    event DonationReceived(address indexed donor, address indexed creator, uint256 amount);
    event Withdrawn(address indexed creator, uint256 amount);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function registerCreator(string calldata _name) external {
        require(!creators[msg.sender].isRegistered, "Creator is already registered");
        require(bytes(_name).length > 0, "Name cannot be empty");

        creators[msg.sender] = Creator({
            name: _name,
            isRegistered: true
        });

        emit CreatorRegistered(msg.sender, _name);
    }

    function uploadContent(
        string calldata _ipfsHash,
        string calldata _title,
        string calldata _fileType,
        string calldata _contentCategory
    ) external onlyRegisteredCreator {
        require(bytes(_ipfsHash).length > 0, "IPFS hash cannot be empty");
        require(bytes(_title).length > 0, "Title cannot be empty");
        require(bytes(_contentCategory).length > 0, "Content category cannot be empty");

        uint256 contentIndex = contentByCreator[msg.sender].length;

        Content memory newContent = Content({
            creator: msg.sender,
            ipfsHash: _ipfsHash,
            title: _title,
            fileType: _fileType,
            currentDonation: 0,
            donatorsCount: 0,
            contentCategory: _contentCategory
        });

        contentByCategory[_contentCategory].push(newContent);
        contentByCreator[msg.sender].push(newContent);
        contentIndexByHash[msg.sender][_ipfsHash] = contentIndex;

        emit ContentUploaded(msg.sender, _ipfsHash, _title, _contentCategory);
    }

    function donate(address creatorAddress, string calldata ipfsHash) external payable {
        require(creators[creatorAddress].isRegistered, "Recipient is not a registered creator");
        require(msg.value > 0, "Donation amount must be greater than zero");

        uint256 contentIndex = contentIndexByHash[creatorAddress][ipfsHash];
        require(contentIndex < contentByCreator[creatorAddress].length, "Content not found");

        Content storage content = contentByCreator[creatorAddress][contentIndex];

        // Update donation amount
        content.currentDonation += msg.value;

        // Update donator count if this is the first donation from this donor for this content
        if (!donors[msg.sender][contentIndex]) {
            content.donatorsCount += 1;
            donors[msg.sender][contentIndex] = true;
        }

        emit DonationReceived(msg.sender, creatorAddress, msg.value);
    }

    function withdraw(uint256 amount) external onlyRegisteredCreator {
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(address(this).balance >= amount, "Insufficient ETH balance in contract");

        uint256 fee = (amount * 2) / 100;
        uint256 netAmount = amount - fee;

        // Transfer the net amount to the creator
        payable(msg.sender).transfer(netAmount);

        emit Withdrawn(msg.sender, netAmount);
    }

    modifier onlyRegisteredCreator() {
        require(creators[msg.sender].isRegistered, "Not registered as a creator");
        _;
    }

    receive() external payable {
        // ETH sent directly to the contract will not trigger any action
    }

    function withdrawETH() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function getCreator(address _creatorAddress) external view returns (string memory name, bool isRegistered) {
        Creator memory creator = creators[_creatorAddress];
        return (creator.name, creator.isRegistered);
    }

    function getContentByCategory(string memory _category) external view returns (Content[] memory) {
        return contentByCategory[_category];
    }

    function getContentByCreator(address _creatorAddress) external view returns (Content[] memory) {
        return contentByCreator[_creatorAddress];
    }
}
