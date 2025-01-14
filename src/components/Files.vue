<template>
    <div class="tree-view">
        <ol class="breadcrumb">
          <breadcrumb @changePathUp="changePathUp" :stack="stack" :isGit="isGit" v-if="showBreadcrumb"></breadcrumb>
          <div class="breadcrumb-buttons">
              <button v-on:click="newAction()" v-if="!isGit" type="button" class="btn btn-primary"><icon icon="add_circle"/> New</button>
              <button v-on:click="uploadAction()" v-if="!isGit" type="button" class="btn btn-primary"><icon icon="file_upload"/> Upload</button>
              <input type="file" multiple="multiple" style="display: none" ref="file" @change="handleUploadButton" />
          </div>
        </ol>

        <div class="tree-view-tree-content"
             @dragenter.stop.prevent="isDragEnter = true"
             @dragover.stop.prevent="() => {}"
             @dragleave.stop.prevent="isDragEnter = false"
             @drop.stop.prevent="handleDrop">
            <vue-good-table
              :fixed-header="true"
              max-height="100%"
              :columns="columns"
              :rows="items">
              <template #table-row="props">
                <span v-if="props.column.field == 'name'" :class="props.column.field">
                  <a v-on:click.prevent="$emit('changePath', props.row)" :href="props.row.href" :class="'tree-item-' + props.row.type + ' ' + (props.row.isSymbolicLink ? 'tree-item-symlink' : '')" >
                    {{ props.row.name }}
                  </a>
                </span>
                <span v-else-if="props.column.field == 'icon'" :class="props.column.field">
                  <a v-on:click.prevent="$emit('changePath', props.row)" :href="props.row.href" :class="'tree-item-' + props.row.type + ' ' + (props.row.isSymbolicLink ? 'tree-item-symlink' : '')" >
                    <icon :icon="props.row.icon"/>
                  </a>
                </span>
                <span v-else-if="props.column.field == 'action'" class="btn-group">
                  <a v-if="props.row.type == 'blob'" class="download btn btn-default btn-sm" title="Download" :href="props.row.downloadHref"><icon icon="file_download"/></a>
                  <a v-if="(!props.row.isGit) && (props.row.type == 'blob' || props.row.size == 0)" class="trash-o btn btn-default btn-sm" title="Delete" target="_blank" v-on:click.prevent="showDeleteDialog(props.row)" :href="props.row.href"><icon icon="delete"/></a>
                  <a v-if="!props.row.isGit && (props.row.name != '..')" class="i-cursor btn btn-default btn-sm" title="Move/Rename" target="_blank" v-on:click.prevent="showRenameDialog(props.row)" :href="props.row.href"><icon icon="drive_file_rename_outline"/></a>
                  <a v-if="!props.row.isGit && (props.row.name != '..')" class="external-link btn btn-default btn-sm" title="Open in a new window" target="_blank" :href="props.row.href"><icon icon="open_in_new"/></a>
                </span>
                <span v-else-if="props.column.field == 'size'" :class="props.column.field">
                  {{ props.row.formattedSize }}
                </span>
                <span v-else :class="props.column.field">
                  {{ props.formattedRow[props.column.field] }}
                </span>
              </template>
            </vue-good-table>
        </div>
        <rename-dialog ref="renameDialog" @refresh="refresh"></rename-dialog>
        <delete-dialog ref="deleteDialog" @refresh="refresh"></delete-dialog>
    </div>
</template>
<style>
.tree-view {
    flex: 1 1 0;
    -webkit-flex: 1 1 0;
    flex-direction: column;
    -webkit-flex-direction: column;
    display: flex;
    display: -webkit-flex;
    min-height: 0;
    min-width: 0;
    height: 100%;
}
.tree-view .breadcrumb {
    padding: 0.5rem 1rem 0.5rem 1rem;
    margin-bottom: 0;
    border-radius: 0px;
}
.tree-view .breadcrumb li {
    margin-top: 0.6rem;
    margin-bottom: 0.6rem;
}
.tree-view .breadcrumb a {
    text-decoration: none;
    cursor: pointer;
}
.tree-view .breadcrumb-buttons {
    float: right;
}
.tree-view .breadcrumb-buttons .btn {
    margin-left: 0.5em;
}
.tree-view-tree-content {
    margin: 0;
    height: inherit;
    background-color: #fff;
}
.tree-view-tree-content a:hover {
    text-decoration: none;
}
.tree-view-tree-content .icon {
    line-height: 2em;
}
.tree-view-tree-content .icon a,
.tree-view-tree-content .name a,
.tree-view-tree-content .action a {
    color: inherit;
}
.tree-view .tree-item-symlink {
    font-style: italic;
}
.tree-view-tree-content .btn .material-icons {
    margin-right: 0;
}
</style>
<script>
import axios from 'axios';
import { defineComponent } from 'vue';
import { VueGoodTable } from 'vue-good-table-next';
// import 'vue-good-table-next/dist/vue-good-table-next.css';
import { basename, normalize, prepareHref, git } from '../commons';
import { TreeEntry } from '../tree_entry';
import Icon from './Icon.vue';
import Breadcrumb from './Breadcrumb.vue';
import RenameDialog from './dialogs/RenameDialog.vue';
import DeleteDialog from './dialogs/DeleteDialog.vue';

export default defineComponent({
    components: {
        'icon': Icon,
        'breadcrumb': Breadcrumb,
        'vue-good-table': VueGoodTable,
        'rename-dialog': RenameDialog,
        'delete-dialog': DeleteDialog,
    },
    props: [ 'stack', 'config', 'isGit', 'showBreadcrumb' ],
    data() {
        return {
            items: [], // tree items (blobs/trees)
            isDragEnter: false,
            columns: [
                {
                  label: '',
                  field: 'icon',
                  width: '20px',
                  sortable: true
                },
                {
                  label: 'Name',
                  field: 'name',
                  thClass: 'vgt-right-align',
                  filterOptions: {
                      enabled: true
                  }
                },
                {
                  label: 'Modified',
                  field: 'mtime',
                  thClass: 'vgt-right-align',
                  tdClass: 'vgt-right-align',
                  filterOptions: {
                      enabled: true
                  }
                },
                {
                  label: 'Size',
                  field: 'size',
                  thClass: 'vgt-right-align',
                  type: 'number'
                },
                {
                  label: 'Actions',
                  field: 'action',
                  thClass: 'vgt-right-align',
                  tdClass: 'vgt-right-align',
                  sortable: false
                }
            ]
        }
    },
    methods: {
        showRenameDialog(item) {
            // Show Move/Rename file dialog
            this.$refs.renameDialog.showDialog(item.object);
        },
        showDeleteDialog(item) {
            // Show Delete file dialog
            this.$refs.deleteDialog.showDialog(item.object);
        },
        newAction() {
            // New file button action
            const item = { name: '✧', type: 'blob', object: (this.stack.last().object || '') + '/✧' };
            this.$emit('changePath', item);
        },
        uploadAction() {
            // Upload button action
            this.$refs.file.click();
        },
        changePathUp(index) {
            // Change directory to a parent directory (for breadcrum)
            this.$emit('changePathUp', index);
        },
        refresh() {
            console.log("Files.refresh");
            // Update tree view
            let path = null;
            const last = this.stack.last();
            if (last.type != 'blob') {
                if (this.isGit) { // git
                    path = 'tree' + normalize('git/' + last.object);
                } else { // local
                    path = 'tree' + normalize('files' + (last.object || ''));
                }
                // Get tree items
                axios.get(prepareHref(path), { params: { long: true }})
                     .then((response) => {
                        let blobs = []; // files
                        let trees = []; // directories
                        response.data.value.forEach((part) => {
                            let item = new TreeEntry(part, this.isGit, last.object);
                            if (item.type == 'tree') {
                                trees.push(item);
                            } else {
                                blobs.push(item);
                            }
                        });
                        // Sort files and directories
                        const compare = (a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase());
                        blobs.sort(compare);
                        trees.sort(compare);
                        // Add link to parent directory on top
                        if (this.stack.parent() || (last.object !== undefined && last.object.startsWith('/')) ) {
                            trees.unshift({ type: 'tree', name: '..', isSymbolicLink: false, icon: 'folder', href: '#' });
                        }
                        this.items = trees.concat(blobs);
                        this.$emit('loaded', false); // close the spinner
                  })
                  .catch(error => {
                        this.$emit('loaded', false); // close the spinner
                        console.log(error);
                  })
            }
        },
        handleDrop($event) {
            // Upload files (drag and drop)
            this.isDragEnter = false;
            // Convert FileList into Array
            const files = [...$event.dataTransfer.files];
            this.uploadFiles(files);
        },
        handleUploadButton($event) {
            // Upload files (upload button)
            const files = Array.from($event.target.files);
            this.uploadFiles(files);
            $event.target.value = '';
        },
        uploadFiles(files) {
            // Upload files
            const self = this;
            if (!this.isGit) {
                files.forEach((file) => {
                    const filename = normalize((self.stack.last().object || '') + '/' + basename(file.name));
                    const payload = file;
                    const options = {
                        headers: {
                            'Content-Type': file.type
                        }
                    };
                    // Upload file
                    axios.post(prepareHref('files' + filename), payload, options)
                         .then((response) => self.refresh())
                         .catch((error) => console.log(error));
                });
            }
        },
    },
    mounted() {
        this.refresh();
    }
})
</script>
