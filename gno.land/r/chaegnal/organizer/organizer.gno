package organizer

import (
	"std"
	"strconv"

	"gno.land/p/demo/avl"
	"gno.land/p/demo/avl/pager"
	"gno.land/p/demo/ownable"
	"gno.land/p/moul/md"
	"gno.land/p/moul/txlink"
	"gno.land/r/sys/users"
)

type AllGroups struct {
	Groups *avl.Tree
}

type FriendGroup struct {
	ID      int
	Title   string
	Owner   *ownable.Ownable
	Friends *avl.Tree
}

type Activity struct {
	ID            int
	Title         string
	Description   string
	AvailableTime []string
	Votes         *avl.Tree
	Participants  *avl.Tree
	Deadline      string
	ChosenTime    string
	Active        bool
}

const (
	pageSize = 5
)

var (
	ListGroups AllGroups
)

func init() {
	ListGroups.Groups = avl.NewTree()
}

func CreateFriendGroup(title string) {
	caller := std.PreviousRealm().Address()

	newGroup := FriendGroup{
		ID:      ListGroups.Groups.Size() + 1,
		Title:   title,
		Owner:   ownable.NewWithAddress(caller),
		Friends: avl.NewTree(),
	}

	newGroup.Friends.Set(strconv.Itoa(newGroup.Friends.Size()+1), caller)

	ListGroups.Groups.Set(strconv.Itoa(newGroup.ID), newGroup)
}

func containsValue(tree *avl.Tree, value string) bool {
	found := false

	tree.Iterate("", "", func(key string, val any) bool {
		addr, ok := val.(std.Address)
		if ok && addr.String() == value {
			found = true
			return true
		}
		return false
	})

	return found
}

func JoinFriendGroup(groupId int) {
	txSender := std.OriginCaller()

	raw, exists := ListGroups.Groups.Get(strconv.Itoa(groupId))
	if !exists {
		panic("Group does not exist")
	}

	group := raw.(FriendGroup)

	if containsValue(group.Friends, txSender.String()) {
		panic("You are already part of this FriendGroup")
	}

	group.Friends.Set(strconv.Itoa(group.Friends.Size()+1), txSender)
	ListGroups.Groups.Set(strconv.Itoa(groupId), group)
}

func displayGroupDetails(key string, value interface{}, out *string) {
	group := value.(*FriendGroup)

	*out += md.Paragraph("Group Title: " + group.Title + " created by: " + group.Owner.Owner().String())
	*out += "\n"
}

func resolveAdressName(addr std.Address) string {
	user := users.ResolveAddress(addr)
	if user != nil {
		return user.Name()
	}
	return addr.String()
}

func displayAllExistingGroups(pageNumber, pageSize int) string {
	var out string

	pager := pager.NewPager(ListGroups.Groups, pageSize, false)

	page := pager.GetPage(pageNumber)

	if page.TotalItems == 0 {
		out += "No friend groups available.\n"
		return out
	}

	for _, item := range page.Items {
		group, ok := item.Value.(FriendGroup)
		if !ok {
			continue
		}

		author := resolveAdressName(group.Owner.Owner())

		out += md.H3("Group: "+group.Title+" - By: "+author) + "\n"
		out += md.Paragraph("Number of friends in the group: "+strconv.Itoa(group.Friends.Size())) + "\n"
		out += md.Link("Join Group", txlink.Call("JoinFriendGroup", "groupId", strconv.Itoa(group.ID)))
		out += md.HorizontalRule() + "\n"
	}

	out += page.Picker("/groups")

	return out
}

func displayJoinedGroups(caller std.Address) string {
	var out string
	found := false

	out += md.H3("Your Joined Groups") + "\n"
	out += "| Title | Created By | Members | Inspect |\n"
	out += "|-------|------------|---------|---------|\n"

	ListGroups.Groups.Iterate("", "", func(key string, val any) bool {
		group := val.(FriendGroup)

		// if containsValue(group.Friends, caller.String()) || group.Owner.Owner() == caller {
		author := resolveAdressName(group.Owner.Owner())
		out += "| " + group.Title + " | " + author + " | " + strconv.Itoa(group.Friends.Size()) + " | " + md.Link("View Group", "/r/chaegnal/organizer/groups?groupId="+strconv.Itoa(group.ID)) + " |\n"
		found = true
		// }

		return false
	})

	if !found {
		out = md.Paragraph("You haven't joined any groups yet.")
	}

	return out
}

func Render(rawURL string) string {
	var out string

	pageNumber, size, err := pager.NewPager(ListGroups.Groups, pageSize, false).ParseQuery(rawURL)
	if err != nil {
		pageNumber = 1
	}

	out += md.H1("Welcome to Friendly Organizer")
	out += md.Paragraph("Here you can join and create Friend Group to organize your next hangout")

	out += displayJoinedGroups(std.PreviousRealm().Address())

	out += md.H2("List of Friend Groups")

	out += displayAllExistingGroups(pageNumber, size)

	return out
}
