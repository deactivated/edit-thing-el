# edit-thing.el

`edit-thing.el` is like `narrow-to-region` on steroids.

Rather than merely narrowing the current buffer, or using narrowing an
indirect buffer, `edit-thing` will synchronize the contents of a
region with an entirely independent buffer.

Although this strategy is decidedly more heavy-weight, it is
compatible with even the most finicky major modes. `edit-thing` can
also "dedent" the edit-buffer to improve indentation behavior when
editing blocks of code.

## Installation

    (require 'edit-thing)`

## Usage

Select a region and invoke `(edit-thing-edit-region)`.
