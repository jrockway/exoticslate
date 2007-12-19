// Breaking out smaller test failures from big-formatting-roundtrip.t

var t = new Test.Wikiwyg();

t.plan(10);

t.run_roundtrip('wikitext');
t.run_roundtrip('wikitext1', 'wikitext2');

/* Test
=== 2x2 Simple Table
--- wikitext
| one | two |
| three | four |

=== List in a table
--- wikitext
| one | 
* 1
* two | three | four |

=== List in a table
--- wikitext
| 
* 1
* two |

=== Big formatting multiline table
--- wikitext
Multiline cells

| this | that | the other |
| one fish
two fish | red

fish | [blue dotted underlined]
_fish_ |

=== Wafl in tables
--- SKIP
--- wikitext
| Table of contents | 
{toc: }|
| Include page | 
{include: [page_title]}
|
| Recent changes | 
{recent_changes: }|

=== Links in tables
--- wikitext
| file://datastore/on/disk/645810-343a5 |
| http://example.com/remote/datastore/541422-5432 |

=== table has only one line afterwards
--- wikitext
| foo |

bar bar

=== table has only one line afterwards
--- wikitext
| foo |

=== Table with a list in a cell
--- wikitext
| foo | 
* xxx
* xxx |

=== Multiple spaces at end of line get stripped
--- wikitext1
| foo |    
* xxx
| bar |
--- wikitext2
| foo |

* xxx

| bar |

=== Single space at end of normal row line gets stripped
--- wikitext1
| foo | 
| bar |

pipe => |
--- wikitext2
| foo |
| bar |

pipe => |

*/
