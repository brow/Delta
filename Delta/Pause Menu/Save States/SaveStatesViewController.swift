//
//  SaveStatesViewController.swift
//  Delta
//
//  Created by Riley Testut on 1/23/16.
//  Copyright © 2016 Riley Testut. All rights reserved.
//

import UIKit
import CoreData

import DeltaCore
import Roxas

protocol SaveStatesViewControllerDelegate: class
{
    func saveStatesViewControllerActiveGame(saveStatesViewController: SaveStatesViewController) -> Game
    func saveStatesViewController(saveStatesViewController: SaveStatesViewController, updateSaveState saveState: SaveState)
    func saveStatesViewController(saveStatesViewController: SaveStatesViewController, loadSaveState saveState: SaveState)
}

class SaveStatesViewController: UICollectionViewController
{
    weak var delegate: SaveStatesViewControllerDelegate?
    
    private var backgroundView: RSTBackgroundView!
    
    private var prototypeCell = GridCollectionViewCell()
    private var prototypeCellWidthConstraint: NSLayoutConstraint!
    
    private let fetchedResultsController: NSFetchedResultsController
    
    private let dateFormatter: NSDateFormatter
    
    required init?(coder aDecoder: NSCoder)
    {
        let fetchRequest = SaveState.fetchRequest()
        fetchRequest.returnsObjectsAsFaults = false
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: SaveStateAttributes.creationDate.rawValue, ascending: true)]
        
        self.fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DatabaseManager.sharedManager.managedObjectContext, sectionNameKeyPath: nil, cacheName: nil)
        
        self.dateFormatter = NSDateFormatter()
        self.dateFormatter.timeStyle = .ShortStyle
        self.dateFormatter.dateStyle = .ShortStyle
        
        super.init(coder: aDecoder)
        
        self.fetchedResultsController.delegate = self
    }
}

extension SaveStatesViewController
{
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        self.backgroundView = RSTBackgroundView(frame: self.view.bounds)
        self.backgroundView.hidden = true
        self.backgroundView.autoresizingMask = [.FlexibleWidth, .FlexibleHeight]
        self.backgroundView.textLabel.text = NSLocalizedString("No Save States", comment: "")
        self.backgroundView.textLabel.textColor = UIColor.whiteColor()
        self.backgroundView.detailTextLabel.text = NSLocalizedString("You can create a new save state by pressing the + button in the top right.", comment: "")
        self.backgroundView.detailTextLabel.textColor = UIColor.whiteColor()
        self.view.insertSubview(self.backgroundView, atIndex: 0)
        
        let collectionViewLayout = self.collectionViewLayout as! GridCollectionViewLayout
        let averageHorizontalInset = (collectionViewLayout.sectionInset.left + collectionViewLayout.sectionInset.right) / 2
        let portraitScreenWidth = UIScreen.mainScreen().coordinateSpace.convertRect(UIScreen.mainScreen().bounds, toCoordinateSpace: UIScreen.mainScreen().fixedCoordinateSpace).width
        
        // Use dimensions that allow two cells to fill the screen horizontally with padding in portrait mode
        // We'll keep the same size for landscape orientation, which will allow more to fit
        collectionViewLayout.itemWidth = (portraitScreenWidth - (averageHorizontalInset * 3)) / 2
        
        // Manually update prototype cell properties
        self.prototypeCellWidthConstraint = self.prototypeCell.contentView.widthAnchor.constraintEqualToConstant(collectionViewLayout.itemWidth)
        self.prototypeCellWidthConstraint.active = true
        
        self.updateBackgroundView()
    }
    
    override func viewWillAppear(animated: Bool)
    {
        if self.fetchedResultsController.fetchedObjects == nil
        {
            do
            {
                try self.fetchedResultsController.performFetch()
            }
            catch let error as NSError
            {
                print(error)
            }
        }
        
        self.updateBackgroundView()
        
        super.viewWillAppear(animated)
    }
    
    override func didReceiveMemoryWarning()
    {
        super.didReceiveMemoryWarning()
    }
}

private extension SaveStatesViewController
{
    func updateBackgroundView()
    {
        if let fetchedObjects = self.fetchedResultsController.fetchedObjects where fetchedObjects.count > 0
        {
            self.backgroundView.hidden = true
        }
        else
        {
            self.backgroundView.hidden = false
        }
    }
}

private extension SaveStatesViewController
{
    func configureCollectionViewCell(cell: GridCollectionViewCell, forIndexPath indexPath: NSIndexPath)
    {
        let saveState = self.fetchedResultsController.objectAtIndexPath(indexPath) as! SaveState
        
        cell.imageView.backgroundColor = UIColor.whiteColor()
        cell.imageView.image = UIImage(named: "DeltaPlaceholder")
        
        cell.maximumImageSize = CGSizeMake(self.prototypeCellWidthConstraint.constant, (self.prototypeCellWidthConstraint.constant / 4.0) * 3.0)
        
        cell.textLabel.textColor = UIColor.whiteColor()
        cell.textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        
        let name = saveState.name ?? self.dateFormatter.stringFromDate(saveState.modifiedDate)
        cell.textLabel.text = name
    }
}

private extension SaveStatesViewController
{
    @IBAction func addSaveState()
    {
        guard let delegate = self.delegate else { return }
        
        let backgroundContext = DatabaseManager.sharedManager.backgroundManagedObjectContext()
        backgroundContext.performBlock {
            
            let identifier = NSUUID().UUIDString
            let date = NSDate()
            
            var game = delegate.saveStatesViewControllerActiveGame(self)
            game = backgroundContext.objectWithID(game.objectID) as! Game
            
            let saveState = SaveState.insertIntoManagedObjectContext(backgroundContext)
            saveState.identifier = identifier
            saveState.filename = identifier
            saveState.creationDate = date
            saveState.modifiedDate = date
            saveState.game = game
            
            self.updateSaveState(saveState)
        }
    }
    
    func updateSaveState(saveState: SaveState)
    {
        self.delegate?.saveStatesViewController(self, updateSaveState: saveState)
        saveState.managedObjectContext?.saveWithErrorLogging()
    }
}

extension SaveStatesViewController
{
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        let section = self.fetchedResultsController.sections![section]
        return section.numberOfObjects
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(RSTGenericCellIdentifier, forIndexPath: indexPath) as! GridCollectionViewCell
        self.configureCollectionViewCell(cell, forIndexPath: indexPath)
        return cell
    }
}

extension SaveStatesViewController
{
    override func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        let saveState = self.fetchedResultsController.objectAtIndexPath(indexPath) as! SaveState
        self.delegate?.saveStatesViewController(self, loadSaveState: saveState)
    }
}

extension SaveStatesViewController: UICollectionViewDelegateFlowLayout
{
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize
    {
        self.configureCollectionViewCell(self.prototypeCell, forIndexPath: indexPath)
        
        let size = self.prototypeCell.contentView.systemLayoutSizeFittingSize(UILayoutFittingCompressedSize)
        return size
    }
}

extension SaveStatesViewController: NSFetchedResultsControllerDelegate
{
    func controllerDidChangeContent(controller: NSFetchedResultsController)
    {
        self.collectionView?.reloadData()
        self.updateBackgroundView()
    }
}